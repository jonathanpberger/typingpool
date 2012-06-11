#!/usr/bin/env ruby

$:.unshift File.join(File.dirname(File.dirname($0)), 'lib')

require 'typingpool'
require 'typingpool/test'
require 'fileutils'

class TestFiler < Typingpool::Test

  def test_filer_base
    path = File.join(fixtures_dir, 'config-1')
    assert(filer = Typingpool::Filer.new(path))
    assert_equal(path, "#{filer}")
    assert(text = filer.read)
    assert_match(text, /^amazon:\n/)
    assert_match(text, /transcripts: ~\/Documents\/Transcripts\//)
    assert_match(text, /- mp3\s*$/)
    assert_equal(fixtures_dir, filer.dir.path)
    path = File.join(fixtures_dir, 'filer-temp')
    assert(filer = Typingpool::Filer.new(path))
    assert_nil(filer.read)
    data = "foo\nbar\nbaz."
    begin
      assert(filer.write(data))
      assert_equal(data, filer.read)
      assert(path = filer.mv!(File.join(fixtures_dir, 'filer-temp-2')))
      assert(File.exists? filer.path)
      assert_equal('filer-temp-2', File.basename(filer.path))
    ensure
      File.delete(path)
    end #begin
  end

  def test_filer_csv
    path = File.join(fixtures_dir, 'tp_review_assignment.csv')
    assert(filer = Typingpool::Filer::CSV.new(path))
    assert_equal(path, "#{filer}")
    assert(data = filer.read)
    assert_instance_of(Array, data)
    assert_instance_of(Hash, data.first)
    assert_respond_to(filer, :each)
    assert_respond_to(filer, :map)
    assert_respond_to(filer, :select)
    assert(data.first['audio_url'])
    assert_match(data.first['audio_url'], /^https?:\/\/\w/)
    assert(filer.select{|r| r['audio_url'] }.count > 0)
    path = File.join(fixtures_dir, 'filer-temp')
    assert(filer2 = Typingpool::Filer::CSV.new(path))
    assert_nil(filer2.read)
    begin
      assert(filer2.write(data))
      assert_equal(Typingpool::Filer.new(filer.path).read, Typingpool::Filer.new(filer2.path).read)
      assert_equal(filer.count, filer2.count)
      filer2.each! do |row|
        row['audio_url'] = row['audio_url'].reverse
      end
      rewritten = Typingpool::Filer.new(filer2.path).read
      assert(Typingpool::Filer.new(filer.path).read != rewritten)
keys = filer2.first.keys
      filer2.write_arrays(filer2.map{|row| keys.map{|key| row[key] } }, keys)
      assert_equal(rewritten, Typingpool::Filer.new(filer2.path).read)
    ensure
      File.delete(path)
    end #begin
  end

  def test_filer_audio
    mp3 = Typingpool::Filer::Audio.new(files_from(File.join(template_dir, 'audio', 'mp3')).first)
    wma = Typingpool::Filer::Audio.new(files_from(File.join(template_dir, 'audio', 'wma')).first)
    assert(mp3.mp3?)
    assert(not(wma.mp3?))
    dest = Typingpool::Filer::Audio.new(File.join(fixtures_dir, 'filer-temp.mp3'))
    assert(converted = wma.to_mp3(dest))
    begin
      assert_equal(dest.path, converted.path)
      assert_equal(35, wma.bitrate)
      assert(converted.bitrate)
      assert(converted.mp3?)
    ensure
      File.delete(dest)
    end #begin
    assert(chunks = mp3.split('0.25', 'filer-temp', Typingpool::Filer::Dir.new(fixtures_dir)))
    begin
      assert(not(chunks.to_a.empty?))
      assert_equal(3, chunks.count)
      chunks.each{|chunk| assert(File.exists? chunk) }
      assert(chunks.first.offset)
      assert_match(chunks.first.offset, /0\.00\b/)
      assert_match(chunks.to_a[1].offset, /0\.25\b/)
    ensure
      chunks.each{|chunk| File.delete(chunk) }
    end #begin
  end

  def files_from(dir)
    Dir.entries(dir).map{|entry| File.join(dir, entry) }.select{|path| File.file? path }.reject{|path| path.match(/^\./) }
  end

  def test_filer_files_base
    file_selector = /tp[_-]collect/
    dir = fixtures_dir
    files = files_from(dir).select{|path| path.match(file_selector) }
    dir = File.join(fixtures_dir, 'vcr')
    files.push(*files_from(dir).select{|path| path.match(file_selector) })
    assert(files.count > 0)
    assert(filer = Typingpool::Filer::Files.new(files.map{|path| Typingpool::Filer.new(path) }))
    assert_equal(filer.files.count, files.count)
    assert_respond_to(filer, :each)
    assert_respond_to(filer, :select)
    assert_respond_to(filer, :map)
    assert_instance_of(Typingpool::Filer::Files::Audio, filer.as(:audio))
  end

  def test_filer_files_audio
    mp3s = files_from(File.join(template_dir, 'audio', 'mp3')).map{|path| Typingpool::Filer::Audio.new(path) }
    wmas = files_from(File.join(template_dir, 'audio', 'wma')).map{|path| Typingpool::Filer::Audio.new(path) }
    assert(mp3s.count > 0)
    assert(wmas.count > 0)
    assert(filer_mp3 = Typingpool::Filer::Files::Audio.new(mp3s))
    assert(filer_wma = Typingpool::Filer::Files::Audio.new(wmas))
    assert_equal(mp3s.count, filer_mp3.files.count)
    assert_equal(wmas.count, filer_wma.files.count)
    temp_path = File.join(fixtures_dir, 'filer-temp')
    FileUtils.mkdir(temp_path)
    begin
      dest_filer = Typingpool::Filer::Dir.new(temp_path)
      assert(filer_conversion = filer_wma.to_mp3(dest_filer))
      assert_equal(filer_wma.files.count, filer_conversion.files.count)
      assert_equal(filer_wma.files.count, filer_conversion.select{|file| File.exists? file }.count)
      assert_equal(filer_wma.files.count, filer_conversion.select{|file|  file.mp3? }.count)
      assert_equal(filer_conversion.files.count, dest_filer.files.count)
    ensure
      FileUtils.rm_r(temp_path)
    end #begin
    temp_path = "#{temp_path}.mp3"
    assert(filer_merged = filer_mp3.merge(Typingpool::Filer.new(temp_path)))
    begin
      assert(File.size(filer_merged) > File.size(filer_mp3.first))
      assert(filer_merged.mp3?)
      assert(filer_merged.path != filer_mp3.first.path)
      assert(filer_merged.path != filer_mp3.to_a[1].path)
    ensure
      File.delete(temp_path)
    end #begin
  end

  def test_filer_dir
    assert(dir = Typingpool::Filer::Dir.new(fixtures_dir))
    assert_equal(fixtures_dir, dir.path)
    dir2_path = File.join(fixtures_dir, 'doesntexist')
    assert(not(File.exists? dir2_path))
    assert(dir2 = Typingpool::Filer::Dir.new(dir2_path))
    dir3_path = File.join(fixtures_dir, 'filer-dir-temp')
    assert(not(File.exists? dir3_path))
    begin
      assert(dir3 = Typingpool::Filer::Dir.create(dir3_path))
      assert(File.exists? dir3_path)
      assert_instance_of(Typingpool::Filer::Dir, dir3)
      assert_nil(dir2 = Typingpool::Filer::Dir.named(File.basename(dir2_path), File.dirname(dir2_path)))
      assert(dir3 = Typingpool::Filer::Dir.named(File.basename(dir3_path), File.dirname(dir3_path)))
      assert_instance_of(Typingpool::Filer::Dir, dir3)
      assert_equal(dir3_path, dir3.to_s)
      assert_equal(dir3_path, dir3.to_str)
      assert(filer = dir3.file('doesntexist'))
    ensure
      FileUtils.rmdir(dir3_path)
    end #begin
    assert(filer = dir.file('vcr', 'tp-collect-1.yml'))
    assert(File.exists? filer.path)
    assert_instance_of(Typingpool::Filer, filer)
    assert(csv = dir.csv('tp_collect_assignment.csv'))
    assert(File.exists? csv.path)
    assert_instance_of(Typingpool::Filer::CSV, csv)
    dir4 = Typingpool::Filer::Dir.new(audio_dir)
    assert(audio = dir4.audio('mp3', 'interview.1.mp3'))
    assert(File.exists? audio.path)
    assert_instance_of(Typingpool::Filer::Audio, audio)
    assert(filers = dir.files)
    assert(not(filers.empty?))
    assert_kind_of(Typingpool::Filer, filers.first)
    assert(File.exists? filers.first.path)
    dir_files = Dir.entries(dir.path).map{|entry| File.join(dir.path, entry)}.select{|path| File.file?(path) }.reject{|path| File.basename(path).match(/^\./) }
    assert_equal(dir_files.count, filers.count)
    assert(dir5 = dir.subdir('vcr'))
    assert(File.exists? dir5.path)
    assert_instance_of(Typingpool::Filer::Dir, dir5)
  end

end #TestFiler