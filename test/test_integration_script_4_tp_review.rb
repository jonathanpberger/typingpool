#!/usr/bin/env ruby

$:.unshift File.join(File.dirname(File.dirname($0)), 'lib')

require 'typingpool'
require 'typingpool/test'

class TestTpReview < Typingpool::Test::Script

  def test_tp_review
    in_temp_tp_dir do |dir|
      skip_if_no_upload_credentials('tp-review integration test')
      skip_if_no_amazon_credentials('tp-review integration test')
      tp_make(dir)
      copy_fixtures_to_temp_tp_dir(dir, 'tp_review_')
      assert(File.exists? File.join(temp_tp_dir_project_dir(dir), 'data','sandbox-assignment.csv'))
      project = temp_tp_dir_project(dir)
        assert_equal(7, project.local.file('data','sandbox-assignment.csv').as(:csv).reject{|assignment| assignment['hit_id'].to_s.empty? }.count)
      begin
        output = nil
        output = tp_review_with_fixture(dir, File.join(fixtures_dir, 'vcr', 'tp-review-1'), %w(a r a r s q))
        assert_equal(0, output[:status].to_i, "Bad exit code: #{output[:status]} err: #{output[:err]}")
        assert_equal(5, project.local.file('data','sandbox-assignment.csv').as(:csv).reject{|assignment| assignment['hit_id'].to_s.empty? }.count)
        reviews = split_reviews(output[:out])
        assert_match(/Interview\.00\.00/, reviews[1])
        #we can't specify leading \b boundaries because the ansi
        #escape sequences mess that up
        assert_match(/Approved\b/i, reviews[1])
        assert_match(/Interview\.00\.20/, reviews[2])
        assert_match(/reason\b/i, reviews[2])
        assert_match(/Rejected\b/i, reviews[2])
        assert_match(/Interview\.00\.40/, reviews[3])
        assert_match(/Approved\b/i, reviews[3])
        assert_match(/Interview\.01\.00/, reviews[4])
        assert_match(/reason\b/i, reviews[4])
        assert_match(/Rejected\b/i, reviews[4])
        assert_match(/Interview\.01\.20/, reviews[5])
        assert_match(/Skipping\b/i, reviews[5])
        assert_match(/Interview\.02\.00/, reviews[6])
        assert_match(/Quitting\b/i, reviews[6])
        transcript = assert_has_partial_transcript(dir)
        assert_html_has_audio_count(2, transcript)
        assert_assignment_csv_has_transcription_count(2, project, 'sandbox-assignment.csv')
        output = tp_review_with_fixture(dir, File.join(fixtures_dir, 'vcr', 'tp-review-2'), %w(a r))
        assert_equal(0, output[:status].to_i, "Bad exit code: #{output[:status]} err: #{output[:err]}")
        assert_equal(4, project.local.file('data','sandbox-assignment.csv').as(:csv).reject{|assignment| assignment['hit_id'].to_s.empty? }.count)
        reviews = split_reviews(output[:out])
        assert_match(/Interview\.01\.20/, reviews[1])
        assert_match(/Approved\b/i, reviews[1])
        assert_match(/Interview\.02\.00/, reviews[2])
        assert_match(/reason\b/i, reviews[2])
        assert_match(/Rejected\b/i, reviews[2])
        transcript = assert_has_partial_transcript(dir)
        assert_html_has_audio_count(3, transcript)
        assert_assignment_csv_has_transcription_count(3, project, 'sandbox-assignment.csv')
      ensure
        rm_fixtures_from_temp_tp_dir(dir, 'tp_review_')
        tp_finish(dir)
      end #begin
    end #in_temp_tp_dir
  end

  def split_reviews(output)
    output.split(/Transcript for\b/)
  end

end #class TestTpReview
