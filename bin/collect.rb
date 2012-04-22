#!/usr/bin/env ruby

require 'erb'
require 'typingpool'
require 'optparse'

options = {
  :config => Typingpool::Config.file
}

OptionParser.new do |commands|
  options[:banner] = commands.banner = "USAGE: #{File.basename($PROGRAM_NAME)} [--config PATH] [--sandbox]\n"
  commands.on('--sandbox', "Collect from the Mechanical Turk test sandbox") do
    options[:sandbox] = true
  end
  commands.on('--config=PATH', "Default: ~/.typingpool", " A config file") do |config|
    path = File.expand_path(config)
    File.exists?(path) && File.file?(path) or abort "No such file #{path}"
    options[:config] = Typingpool::Config.file(config)
  end
  commands.on('--fixture=PATH', "Optional. For testing purposes only.", "  A VCR ficture for running with mock data.") do |fixture|
    options[:fixture] = fixture
  end
  commands.on('--help', "Display this screen") do
    STDERR.puts commands
    exit
  end
end.parse!

if options[:fixture]
  Typingpool::App.vcr_record(options[:fixture], options[:config])
end

STDERR.puts "Collecting results from Amazon"
Typingpool::Amazon.setup(:sandbox => options[:sandbox], :config => options[:config])
hits = Typingpool::Amazon::HIT.all_approved
#Only pay attention to results that have a local folder waiting to receive them:
projects = {}
need = {}
STDERR.puts "Looking for local project folders to receive results" unless hits.empty?
Typingpool::App.find_projects_waiting_for_hits(hits, options[:config]) do |project, hits|
  Typingpool::App.record_approved_hits_in_project(project, hits)
  out_file = Typingpool::App.create_transcript(project)
  STDERR.puts "Wrote #{out_file} to local folder #{project.name}."
end

if options[:fixture]
  Typingpool::App.vcr_stop
end
