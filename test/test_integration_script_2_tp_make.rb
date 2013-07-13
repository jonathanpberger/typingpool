#!/usr/bin/env ruby

$LOAD_PATH.unshift File.join(File.dirname(File.dirname(__FILE__)), 'lib')

require 'minitest/autorun'
require 'typingpool'
require 'typingpool/test'
require 'open3'

class TestTpMake < Typingpool::Test::Script                   
  def test_abort_with_no_files
    assert_tp_make_abort_match(['--title', 'Foo', '--chunks', '0:20'], /no files/i)
  end

  def test_abort_with_no_title
    assert_tp_make_abort_match(['--file', audio_files[0]], /no title/i)
  end

  def test_abort_with_invalid_title
    assert_tp_make_abort_match(['--file', audio_files[0], '--title', 'Foo/Bar'], /illegal character/i)
  end

  def test_abort_with_no_args
    assert_tp_make_abort_match([], /\bUSAGE:/)
  end

  def assert_tp_make_abort_match(args, regex)
    args.push('--devtest')
    assert_script_abort_match(args, regex) do |args|
      call_tp_make(*args)
    end
  end

  def tp_make_and_upload_with(dir, config_path)
    begin
      tp_make(dir, config_path, 'mp3', false)
      assert(project = temp_tp_dir_project(dir, Typingpool::Config.file(config_path)))
      check_project_files(project)
      check_project_uploads(project)
    ensure
      tp_finish_outside_sandbox(dir, config_path)
    end #begin
    assert_all_assets_have_upload_status(project.local.file('data', 'assignment.csv').as(:csv), ['audio'], 'no') 
  end


  def check_project_uploads(project)
    assignments = project.local.file('data', 'assignment.csv').as(:csv)
    assert_all_assets_have_upload_status(assignments, ['audio'], 'yes')
    assignments.each do |assignment|
      assert(assignment['audio_url'])
      assert(working_url_eventually? assignment['audio_url'])
      assert_equal('yes', assignment['audio_uploaded'])
    end #assignments.each do....
  end

  def check_project_files(project)
    assert(project.local)
    assert(project.local.id)
    assert(project.local.subdir('audio','chunks').to_a.size <= 7)
    assert(project.local.subdir('audio','chunks').to_a.size >= 6)
    assert_equal(project_default[:subtitle], project.local.subtitle)
    assignments = project.local.file('data', 'assignment.csv').as(:csv)
    assert_equal(project.local.subdir('audio','chunks').to_a.size, assignments.count)
    assignments.each do |assignment|
      assert_equal(assignment['project_id'], project.local.id)
      assert_equal(assignment['unusual'].split(/\s*,\s*/), project_default[:unusual])
      project_default[:voice].each_with_index do |voice, i|
        name, description = voice.split(/\s*,\s*/)
        assert_equal(name, assignment["voice#{i+1}"])
        if not(description.to_s.empty?)
          assert_equal(description, assignment["voice#{i+1}title"])
        end
      end #project_default[:voice].each_with_index...
    end #assignments.each do....
  end

  def test_tp_make_audio_handling
    Dir.entries(audio_dir).select{|entry| File.directory?(File.join(audio_dir, entry))}.reject{|entry| entry.match(/^\./) }.each do |subdir|
      in_temp_tp_dir do |dir|
        config_path = self.config_path(dir)
        skip_if_no_upload_credentials('tp-make audio handling test', Typingpool::Config.file(config_path))
        tp_make(dir, config_path, subdir, true)
        assert(project = temp_tp_dir_project(dir, Typingpool::Config.file(config_path)))
        check_project_files(project)
      end #in_temp_tp_dir
    end #Dir.entries
  end

  def test_tp_make_sftp
    in_temp_tp_dir do |dir|
      skip_if_no_sftp_credentials('tp-make SFTP upload test', config)
      tp_make_and_upload_with(dir, config_path(dir))
    end #in_temp_tp_dir do...
  end

  def test_tp_make_s3
    in_temp_tp_dir do |dir|
      skip_if_no_s3_credentials('tp-make S3 integration test', config)
      config_path = setup_s3_config(dir)
      tp_make_and_upload_with(dir, config_path)
    end #in_temp_tp_dir do...
  end 

  def test_fixing_failed_tp_make
    in_temp_tp_dir do |dir|
      config = config_from_dir(dir)
      skip_if_no_s3_credentials('tp-make failed upload integration test', config)
      good_config_path = setup_s3_config(dir)
      bad_config_path = setup_s3_config_with_bad_password(dir)
      assert_raises(Typingpool::Error::Shell) do
        tp_make(dir, bad_config_path, 'mp3')
      end
      project_dir = temp_tp_dir_project_dir(dir)
      assert(File.exists? project_dir)
      assert(File.directory? project_dir)
      assert(File.exists? File.join(project_dir, 'data', 'assignment.csv'))
      originals_dir = File.join(project_dir, 'audio', 'originals')
      refute_empty(Dir.entries(originals_dir).reject{|entry| entry.match(/^\./) }.map{|entry| File.join(originals_dir, entry) }.select{|path| File.file? path })
      assert(project = temp_tp_dir_project(dir))
      assert(assignment_csv = project.local.file('data', 'assignment.csv').as(:csv))
      refute_empty(assignment_csv.to_a)
      assert_all_assets_have_upload_status(assignment_csv, ['audio'], 'maybe')
      assert(audio_urls = assignment_csv.map{|assignment| assignment['audio_url'] })
      refute_empty(audio_urls)
      assert_empty(audio_urls.select{|url| working_url? url })
      begin
        tp_make(dir, good_config_path, 'mp3')
        refute_empty(assignment_csv.read)
        assert_all_assets_have_upload_status(assignment_csv, ['audio'], 'yes')
        refute_empty(audio_urls2 = assignment_csv.map{|assignment| assignment['audio_url'] })
        audio_urls.each_with_index do |original_url, i|
          assert_equal(original_url, audio_urls2[i])
        end
        assert_equal(audio_urls.count, audio_urls2.select{|url| working_url_eventually? url }.count)
      ensure
        tp_finish_outside_sandbox(dir, good_config_path)
      end #begin
      assert_all_assets_have_upload_status(assignment_csv, ['audio'], 'no')
    end #in_temp_tp_dir do...
  end

  def test_audio_files_sorted_correctly
    in_temp_tp_dir do |dir|
      config_path = self.config_path(dir)
      skip_if_no_upload_credentials('tp-make audio file sorting test', Typingpool::Config.file(config_path))
      assert(audio_files('mp3').count > 1)
      correctly_ordered_paths = audio_files('mp3').sort
      tp_make(dir, config_path, 'mp3', true)
      assert(project = temp_tp_dir_project(dir))
      check_project_files(project)
      assert(merged_audio_file = project.local.subdir('audio','originals').files.detect{|filer| filer.path.match(/.\.all\../)})
      assert(File.exists? merged_audio_file)
      actually_ordered_paths = originals_from_merged_audio_file(merged_audio_file)
      assert_equal(correctly_ordered_paths.map{|path| File.basename(path) }, actually_ordered_paths.map{|path| File.basename(path) })
    end #in_temp_tp_dir
  end

  def originals_from_merged_audio_file(path)
    out, err, status = Open3.capture3('mp3splt', '-l', path)
    refute_nil(out)
    refute_empty(out)
    paths = out.scan(/^\/.+\.mp3$/i)
    refute_empty(paths)
    assert(paths.count > 1)
    paths.each{|path| assert(File.exists? path) }
    paths
  end

end #TestTpMake
