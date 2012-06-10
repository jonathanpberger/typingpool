#!/usr/bin/env ruby

require 'optparse'
require 'erb'
require 'typingpool'
require 'stringio'

options = nil
config = nil
configs = [Typingpool::Config.file]

#We need to incorporate command line options immediately into the
#config object, since it checks incoming values for us (see rescue
#clauses).
#
#BUT the user can specify an alternate config file at an arbitrary
#point in the command line options string. So in those cases we loop
#and do it all again. (Actually we loop twice in all cases, because we
#need to do a destructive parse the second time around, and there's no
#way of knowing in advance if we can do a destructive parse the first
#time.)
#
#This solution is DRY and simple. The alternatives tend to be complex
#or repetitive.

2.times do |i|
  config = configs.last
  options = {}
  yet = {}
  option_parser = OptionParser.new do |opts|
    options[:banner] = opts.banner = "USAGE: #{File.basename($PROGRAM_NAME)} PROJECT TEMPLATE [--reward 0.75]\n  [--keyword transcription --keyword mp3...] [--deadline 3h] [--lifetime 2d]\n  [--approval 1d] [--qualify 'approval_rate >= 95' --qualify 'hits_approved > 10'...]\n  [--sandbox] [--currency USD] [--config PATH]\n"
    opts.on('--project=PROJECT', "Required. Path or name within $config_file:transcripts.", "  Also accepted as first argument to script or via STDIN") do |project|
      options[:project] = project
    end
    opts.on('--template=TEMPLATE', "Required. Path or name within dir", "  $config_file:app/templates/assign. Also accepted as first argument to script") do |template|
      options[:template] = template
    end
    opts.on('--reward=DOLLARS', "Default: $config_file:assign:reward.", "  Per chunk. Format N.NN") do |reward|
      reward.match(/(\d+(\.\d+)?)|(\d*\.\d+)/) or abort "Bad --reward format '#{reward}'"
      config.assign.reward = reward
    end
    opts.on('--currency=TYPE', "Default: $config_file:assign:currency") do |currency|
      config.assign.currency = currency
    end
    opts.on('--keyword=WORD', "Default: $config_file:assign:keywords.", "  Repeatable") do |keyword|
      unless yet[:keyword]
        yet[:keyword] = true
        #We ignore keywords from the conf file if the user specified any.
        config.assign.keywords = []
      end
      config.assign.keywords.push(keyword)
    end
    Hash[
         'deadline' => 'Worker time to transcribe',
         'lifetime' => 'Assignment time to expire',
         'approval' => 'Submission time to auto approve'
        ].each do |param, meaning|
      opts.on("--#{param}=TIMESPEC", "Default: $config:assign:#{param}.", "  #{meaning}.", "  N[.N]y|M(onths)|d|h|m(inutes)|s") do |timespec|
        begin
          config.assign.send("#{param}=", timespec)
        rescue Typingpool::Error::Argument => e
          abort "Bad --#{param} '#{timespec}': #{e}"
        end
      end
    end
    opts.on('--qualify=QUALIFICATION', "Default: $config:assign:qualify.","  Repeatable.", "  An RTurk::Qualifications::TYPES +", "  >|<|==|!=|true|exists|>=|<=", "  [+ INT]") do |qualification|
      unless yet[:qualify]
        yet[:qualify] = true
        #We ignore qualifications from the conf file if the user specified any.
        config.assign.qualify = []
      end
      begin
        config.assign.add_qualification(qualification)
      rescue Typingpool::Error::Argument => e
        abort "Bad --qualify '#{qualification}': #{e}"
      end
    end
    opts.on('--sandbox', "Test in Mechanical Turk's sandbox") do
      options[:sandbox] = true
    end
    opts.on('--config=PATH', 'Default: ~/.typingpool') do |path|
      path = File.expand_path(path)
      File.exists?(path) && File.file?(path) or abort "No such file #{path}"
      new_config = Typingpool::Config.file(path)
      configs.push(new_config)
    end
    opts.on('--help', 'Display this screen') do
      STDERR.puts opts
      exit
    end
  end
  if i == 0
    option_parser.parse(ARGV)
  else
    option_parser.parse!
  end
end

options[:banner] += "`#{File.basename($PROGRAM_NAME)} --help` for more information.\n"
options[:banner] = "\n#{options[:banner]}"

positional = %w(project template)
#Anything waiting on STDIN?
if STDIN.fcntl(Fcntl::F_GETFL, 0) == 0
  project = STDIN.gets
  if project
    project.chomp!
    abort "Duplicate project values (STDIN and --project)" if options[:project]
    options[:project] = project
    positional.shift
  end
end
positional.each do |name|
  arg = ARGV.shift
  abort "Duplicate values for #{name}" if (not(arg.to_s.empty?)) && (not(options[name.to_sym].to_s.empty?))
  options[name.to_sym] = arg if options[name.to_sym].to_s.empty?
  abort "Missing required arg #{name}#{options[:banner]}" if options[name.to_sym].to_s.empty?
end
abort "Unexpected argument(s): #{ARGV.join(';')}" if not(ARGV.empty?)

if File.exists?(options[:project])
  config.transcripts = File.dirname(options[:project])
else
  if config.transcripts.to_s.empty?
    abort "Required param 'transcripts' missing from config file '#{config.path}'" 
  end
  options[:project] = File.join(config.transcripts, options[:project])
end
abort "No template specified" if not(options[:template])
begin
  template = Typingpool::Template::Assignment.from_config(options[:template], config)
rescue Typingpool::Error::File::NotExists => e
  abort "Couldn't find the template dir in your config file: #{e}"
rescue Typingpool::Error => e
  abort "Couldn't find your template: #{e}"
end
%w(project).each do |arg|
  abort "No #{arg} at #{options[arg.to_sym]}" if not(File.exists?(options[arg.to_sym]))
end
abort "Project '#{options[:project]}' is not a directory" if not(File.directory?(options[:project]))

project = Typingpool::Project.new(File.basename(options[:project]), config)

abort "Not a project directory at '#{options[:project]}'" if not(project.local)
assignments = project.local.csv('data', 'assignment.csv').read
abort "No data in assignment CSV" if assignments.empty?
abort "No Amazon key+secret in config" if not(config.amazon && config.amazon.key && config.amazon.secret)


#always upload assignment html (can't re-use old ones because params
#may have changed, affecting html output) 
#
#TO DO merge in params with assignments from csv before passing to
#template

STDERR.puts "Figuring out what needs to be assigned"
needed_assignments = {}
unneeded_assignments = {
  :complete => 0,
  :outstanding => 0
}
assignments.each do |assignment|
  if assignment['transcription']
    unneeded_assignments[:complete] += 1
    next
  end
  if assignment['hit_expires_at'].to_s.match(/\S/) #has been assigned previously
    if ((Time.parse(assignment['hit_expires_at']) + assignment['hit_assignments_duration'].to_i) > Time.now)
      #unexpired active HIT - do not reassign
      unneeded_assignments[:outstanding] += 1
      next
    end
  end
  needed_assignments[assignment['audio_url']] = assignment
end

STDERR.puts "#{assignments.size} assignments total"
STDERR.puts "#{unneeded_assignments[:complete]} assignments completed" if unneeded_assignments[:complete] > 0
STDERR.puts "#{unneeded_assignments[:outstanding]} assignments outstanding" if unneeded_assignments[:outstanding] > 0
if needed_assignments.empty?
  STDERR.puts "Nothing to assign"
  exit
else
  STDERR.puts "#{needed_assignments.size} assignments to assign"
end

Typingpool::Amazon.setup(:sandbox => options[:sandbox], :config => config)

#we'll need to re-upload audio if we ran tp-finish on the project
if not(project.local.audio_is_on_www)
  urls = project.remote.put(project.local.subdir('audio','chunks').as(:audio).to_streams, assignments.map{|assignment| project.remote.url_basename(assignment['audio_url']) }) do |file, as|
    puts "Uploading #{File.basename(file)} to #{project.remote.host}/#{project.remote.path} as #{as}"
  end
  project.local.audio_is_on_www = urls.join("\n")
end

#Delete old assignment html for assignments to be re-assigned. We
#can't re-use old assignment HTML because new params (e.g. reward)
#might cause the new HTML to be different
updeleting = needed_assignments.map{|audio_url, assignment| assignment['assignment_url'] }.select{|url| url }
if not(updeleting.empty?)
  STDERR.puts "Deleting old assignment HTML from #{project.remote.host}"
  project.remote.remove_urls(updeleting)
end

STDERR.puts "Uploading assignment HTML to #{project.remote.host}"
needed_assignments_sorted = needed_assignments.values
ios = needed_assignments_sorted.map{|assignment| StringIO.new(template.render(assignment)) }
remote_names = project.create_remote_names(needed_assignments_sorted.map{|assignment| project.class.local_basename_from_url(assignment['audio_url']) + '.html' })
project.remote.put(ios, remote_names).each_with_index do |assignment_url, i|
  needed_assignments_sorted[i]['assignment_url'] = assignment_url
end

STDERR.puts 'Assigning'
hits = []
needed_assignments_sorted.each do |assignment|
  question = Typingpool::Amazon::Question.new(assignment['assignment_url'], template.render(assignment))
  begin
    hit = Typingpool::Amazon::HIT.create(question, config.assign)
  rescue  RTurk::RTurkError => e
    STDERR.puts "Mechanical Turk error: #{e}"
    unless hits.empty?
      STDERR.puts "Rolling back assignments"
      hits.each{|hit| hit.remove_from_amazon }
    end
    abort
  end
  hits.push(hit)
  STDERR.puts "Assigned #{hits.size} / #{needed_assignments.values.size}"
end
Typingpool::App.record_assigned_hits_in_project(project, hits, needed_assignments_sorted.map{|assignment| assignment['assignment_url'] })
