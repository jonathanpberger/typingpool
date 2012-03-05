#!/usr/bin/env ruby

require 'optparse'
require 'uri'
require 'audibleturk'
require 'set'

options = {
  :config => Audibleturk::Config.file,
  :url_at => 'typingpool_url',
  :id_at => 'typingpool_project_id',
}
OptionParser.new do |commands|
  options[:banner] = commands.banner = "USAGE: #{File.basename($PROGRAM_NAME)} PROJECT | --dead\n  [--sandbox]\n  [--config PATH]\n  [--url_at=#{options[:url_at]}] [--id_at=#{options[:id_at]}]\n"
  commands.on('--dead', "Remove ALL expired and rejected results, regardless of project.","  Use in leiu of PROJECT.", "  Removes only Mechanical Turk HITs, not remote audio files") do
    options[:dead] = true
  end
  commands.on('--sandbox', "Test in Mechanical Turk's sandbox") do
    options[:sandbox] = true
  end
  commands.on('--config=PATH', "Default: #{Audibleturk::Config.default_file}.", " A config file") do |path|
    File.exists?(File.expand_path(path)) && File.file?(File.expand_path(path)) or abort "No such file #{path}"
    options[:config] = Audibleturk::Config.file(path)
  end
  commands.on('--url_at=PARAM', "Default: #{options[:url_at]}.", " Name of the HTML form field for audio URLs") do |url_at|
    options[:url_at] = url_at
  end
  commands.on('--id_at=PARAM', "Default: #{options[:id_at]}.", " Name of the HTML form field for project IDs") do |id_at|
    options[:id_at] = id_at
  end
  commands.on('--help', 'Display this screen') do
    $stderr.puts commands 
    exit
  end
end.parse!
options[:banner] += "`#{File.basename($PROGRAM_NAME)} --help` for more information.\n"

project_name_or_path = ARGV[0] 
project_name_or_path = nil if project_name_or_path.to_s.match(/^\s+$/)
abort "Can't specify both PROJECT and --dead" if project_name_or_path && options[:dead]
abort "No PROJECT specified (and no --dead option)\n#{options[:banner]}" if not(project_name_or_path || options[:dead])

project=nil
#Error checking on project info first
if project_name_or_path
  project_path = nil
  if File.exists?(project_name_or_path)
    project_path = project_name_or_path
    options[:config].param['local'] = File.dirname(project_name_or_path)
  else
    project_path = "#{options[:config].local}/#{project_name_or_path}"
  end
  project = Audibleturk::Project.new(File.basename(project_path), options[:config])
  project.local or abort "No such project '#{project_name_or_path}'\n"
  project.local.id or abort "Can't find project id in #{project.local.path}"
end

Audibleturk::Amazon.setup(:sandbox => options[:sandbox], :config => options[:config])
$stderr.puts "Removing from Amazon"
$stderr.puts "  Collecting all results"
#Set up result set, depending on options
results = nil
result_options = {:url_at => options[:url_at], :id_at => options[:id_at]}
if project
  results = Audibleturk::Amazon::Result.all_for_project(project.local.id, result_options)
elsif options[:dead]
  results = Audibleturk::Amazon::Result.all(result_options).select do |result|
    dead = ((result.hit.expired_and_overdue? || result.rejected?) && result.ours?)
    result.to_cache
    dead
  end
end

#Remove the results from Mechanical Turk
fails = []
results.each do |result| 
  $stderr.puts "  Removing HIT #{result.hit_id} (#{result.hit.status})"
  begin
    result.remove_hit 
  rescue Audibleturk::Error::Amazon::UnreviewedContent => e
    fails.push(e)
  else
    $stderr.puts "  Removing from local cache"
    Audibleturk::Amazon::Result.delete_cache(result.hit_id, options[:url_at], options[:id_at])
  end
end
if not (fails.empty?)
  $stderr.puts "Removed " + (results.size - fails.size) + " HITs from Amazon"
  abort "#{fails.size} transcriptions are submitted but unprocessed (#{fails.join('; ')})"
end

#Remove the remote audio files associated with the results and update the assignment.csb associated with the project
if project 
  assignments = project.local.read_csv('assignment')
  assignments.each do |assignment|
    if assignment['hit_expires_at'].to_s.match(/\S/)
      #we don't delete the hit_id because we may need it when building
      #the transcript (if the HIT was approved)
      %w(hit_expires_at hit_assignments_duration).each{|key| assignment[key] = nil }
    end
  end
  project.local.write_csv('assignment', assignments)
  $stderr.puts "Removing audio from #{project.www.host}"
  begin
    project.updelete_audio
  rescue Audibleturk::Error::SFTP => e
    if e.to_s.match(/no such file/)
      $stderr.puts "  No files to remove - may have been removed previously"
    else
      abort "Can't remove remote audio files: #{e}"
    end
  else
    $stderr.puts "  Removed #{assignments.size} audio files from #{project.www.host}"
  end
end