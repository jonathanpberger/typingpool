#!/usr/bin/env ruby

$:.unshift File.join(File.dirname(File.dirname($0)), 'lib')

require 'audibleturk'
require 'audibleturk/test'

class TestTpAssign < Audibleturk::Test::Script
  #TODO: test that qualifications are sent (will need heroic effort
  #(or at least some xml parsing) since rturk doesn't provide an
  #easy way to look at HIT qualifications)
  def test_abort_with_no_input
    assert_raise(Audibleturk::Error::Shell){call_tp_assign}
  end

  def test_abort_with_no_template
    exception = assert_raise(Audibleturk::Error::Shell){call_tp_assign(project_default[:title])}
    assert_match(exception.message, /Missing\b[^\n\r\f]*\btemplate/)
  end

  def test_abort_with_bad_timespec
    exception = assert_raise(Audibleturk::Error::Shell) do
      call_tp_assign(project_default[:title], assign_default[:template], '--lifetime', '4u')
    end
    assert_match(exception.message, /can't convert/i)
  end

  def test_abort_with_bad_qualification
    exception = assert_raise(Audibleturk::Error::Shell) do
      call_tp_assign(project_default[:title], assign_default[:template], '--qualify', 'approval_rate &= 8')
    end
    assert_match(exception.message, /bad --qualify/i)
    assert_match(exception.message, /unknown comparator/i)
    exception = assert_raise(Audibleturk::Error::Shell) do
      call_tp_assign(project_default[:title], assign_default[:template], '--qualify', 'fake_rate > 8', '--sandbox')
    end
    assert_match(exception.message, /bad --qualify/i)
    assert_match(exception.message, /unknown\b[^\n\r\f]*\btype/i)
  end

  def test_tp_assign
    skip_if_no_amazon_credentials('tp-assign test')
    in_temp_tp_dir do |dir|
      tp_make(dir)
      assigning_started = Time.now
      assert_nothing_raised do
        tp_assign(dir)
      end #assert_nothing_raised
      assign_time = Time.now - assigning_started
      config = config_from_dir(dir)
      project = temp_tp_dir_project(dir)
      assert_not_nil(project.local.amazon_hit_type_id)
      setup_amazon(dir)
      results = nil
      assert_nothing_raised{ results = Audibleturk::Amazon::Result.all_for_project(project.local.id, amazon_result_params) }
      assert_equal(project.local.audio_chunks.size, results.size)
      assert_equal(Audibleturk::Utility.timespec_to_seconds(assign_default[:deadline]), results[0].hit.assignments_duration.to_i)
      #These numbers will be apart due to clock differences and
      #timing vagaries of the assignment.
      assert_in_delta((assigning_started + assign_time + Audibleturk::Utility.timespec_to_seconds(assign_default[:lifetime])).to_f, results[0].hit.expires_at.to_f, 60)
      keywords = results[0].hit_at_amazon.keywords
      assign_default[:keyword].each{|keyword| assert_includes(keywords, keyword)}
      assert_nothing_raised{tp_finish(dir)}
      assert_empty(Audibleturk::Amazon::Result.all_for_project(project.local.id, amazon_result_params))
    end # in_temp_tp_dir
  end
end #TestTpAssign