#!/usr/bin/env ruby

$:.unshift File.join(File.dirname(File.dirname($0)), 'lib')

require 'typingpool'
require 'typingpool/test'

class TestTpAssign < Typingpool::Test::Script
  #TODO: test that qualifications are sent (will need heroic effort
  #(or at least some xml parsing) since rturk doesn't provide an
  #easy way to look at HIT qualifications)
  def test_abort_with_no_input
    assert_raise(Typingpool::Error::Shell){call_tp_assign}
  end

  def test_abort_with_no_template
    exception = assert_raise(Typingpool::Error::Shell){call_tp_assign(project_default[:title])}
    assert_match(exception.message, /Missing\b[^\n\r\f]*\btemplate/)
  end

  def test_abort_with_bad_timespec
    exception = assert_raise(Typingpool::Error::Shell) do
      call_tp_assign(project_default[:title], assign_default[:template], '--lifetime', '4u')
    end
    assert_match(exception.message, /can't convert/i)
  end

  def test_abort_with_bad_qualification
    exception = assert_raise(Typingpool::Error::Shell) do
      call_tp_assign(project_default[:title], assign_default[:template], '--qualify', 'approval_rate &= 8')
    end
    assert_match(exception.message, /bad --qualify/i)
    assert_match(exception.message, /unknown comparator/i)
    exception = assert_raise(Typingpool::Error::Shell) do
      call_tp_assign(project_default[:title], assign_default[:template], '--qualify', 'fake_rate > 8', '--sandbox')
    end
    assert_match(exception.message, /bad --qualify/i)
    assert_match(exception.message, /unknown\b[^\n\r\f]*\btype/i)
  end

  def test_tp_assign
    skip_if_no_amazon_credentials('tp-assign integration test')
    skip_if_no_upload_credentials('tp-assign integration test')
    in_temp_tp_dir do |dir|
      tp_make(dir)
      begin
        assigning_started = Time.now
        tp_assign(dir)
        assign_time = Time.now - assigning_started
        config = config_from_dir(dir)
        project = temp_tp_dir_project(dir)
        setup_amazon(dir)
        results = nil
        refute_empty(results = Typingpool::Amazon::HIT.all_for_project(project.local.id))
        assert_equal(project.local.subdir('audio','chunks').to_a.size, results.size)
        assert_equal(Typingpool::Utility.timespec_to_seconds(assign_default[:deadline]), results[0].full.assignments_duration.to_i)
        #These numbers will be apart due to clock differences and
        #timing vagaries of the assignment.
        assert_in_delta((assigning_started + assign_time + Typingpool::Utility.timespec_to_seconds(assign_default[:lifetime])).to_f, results[0].full.expires_at.to_f, 60)
        keywords = results[0].at_amazon.keywords
        assign_default[:keyword].each{|keyword| assert_includes(keywords, keyword)}
        assert(assignment_urls = project.local.csv('data', 'assignment.csv').map{|assignment| assignment['assignment_url'] })
        assert(assignment_html = fetch_url(assignment_urls.first).body)
        assert_match(assignment_html, /\b20[\s-]+second\b/)
      ensure
        tp_finish(dir)
      end #begin
      assert_empty(Typingpool::Amazon::HIT.all_for_project(project.local.id))
    end # in_temp_tp_dir
  end

  def test_aborts_with_unuploaded_audio
    skip_if_no_amazon_credentials('tp-assign unuploaded audio integration test')
    skip_if_no_s3_credentials('tp-assign unuploaded audio integration test')
    in_temp_tp_dir do |dir|
      config = config_from_dir(dir)
      config.to_hash.delete('sftp')
      good_config_path = write_config(config, dir, '.config_s3')
      bad_password = 'f'
      refute_equal(config.to_hash['amazon']['secret'], bad_password)
      config.to_hash['amazon']['secret'] = bad_password
      bad_config_path = write_config(config, dir, '.config_s3_bad')
      assert_raises(Typingpool::Error::Shell) do
        tp_make(dir, bad_config_path, 'mp3')
      end
      project_dir = temp_tp_dir_project_dir(dir)
      assert(File.exists? project_dir)
      assert(File.directory? project_dir)
      exception = assert_raises(Typingpool::Error::Shell) do
        tp_assign(dir)
      end
      assert_match(exception.message, /\baudio\b.+\buploaded\b/i)
    end # in_temp_tp_dir do...
  end


end #TestTpAssign
