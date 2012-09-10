 #!/usr/bin/env gem build 

Gem::Specification.new do |s|
   s.name = 'typingpool'
   s.version = '0.7.0'
   s.date = '2012-09-09'
   s.description = 'An app for transcribing audio using Mechanical Turk'
   s.summary = s.description
   s.authors = ['Ryan Tate']
   s.email = 'ryantate@ryantate.com'
   s.homepage = 'http://github.com/ryantate/typingpool'
   s.required_ruby_version = '>= 1.9.2'
   s.requirements = ['ffmpeg', 'mp3splt', 'mp3wrap']
   s.add_runtime_dependency('rturk', '~> 2.9')
   s.add_runtime_dependency('highline', '>= 1.6')
   s.add_runtime_dependency('nokogiri', '>= 1.5')
   s.add_runtime_dependency('aws-s3', '~> 0.6')
   s.add_runtime_dependency('net-sftp', '>= 2.0.5')
   s.add_runtime_dependency('vcr')
   s.add_runtime_dependency('webmock')
   s.require_path = 'lib'
   s.bindir = 'bin'
   s.executables = ['tp-config',
                    'tp-make',
                    'tp-assign',
                    'tp-review',
                    'tp-collect',
                    'tp-finish']
   s.test_files = ['test/test_unit_amazon.rb',
                   'test/test_unit_config.rb',
                   'test/test_unit_filer.rb',
                   'test/test_unit_project.rb',
                   'test/test_unit_project_local.rb',
                   'test/test_unit_project_remote.rb',
                   'test/test_unit_template.rb',
                   'test/test_unit_transcript.rb']
   s.files = ['Rakefile', 
              'bin/tp-config',
              'bin/tp-make',
              'bin/tp-assign',
              'bin/tp-review',
              'bin/tp-collect',
              'bin/tp-finish',
              'lib/typingpool.rb',
              'lib/typingpool/amazon.rb',
              'lib/typingpool/app.rb',
              'lib/typingpool/config.rb',
              'lib/typingpool/error.rb',
              'lib/typingpool/filer.rb',
              'lib/typingpool/project.rb',
              'lib/typingpool/template.rb',
              'lib/typingpool/test.rb',
              'lib/typingpool/transcript.rb',
              'lib/typingpool/utility.rb',
              'lib/typingpool/templates/assignment/amazon-init.js',
              'lib/typingpool/templates/assignment/interview.html.erb',
              'lib/typingpool/templates/assignment/interview/nameless.html.erb',
              'lib/typingpool/templates/assignment/interview/noisy.html.erb',
              'lib/typingpool/templates/assignment/interview/partials/voices.html.erb',
              'lib/typingpool/templates/assignment/interview/phone.html.erb',
              'lib/typingpool/templates/assignment/main.css',
              'lib/typingpool/templates/assignment/partials/entry.html.erb',
              'lib/typingpool/templates/assignment/partials/footer.html.erb',
              'lib/typingpool/templates/assignment/partials/header.html.erb',
              'lib/typingpool/templates/assignment/partials/labeling-example.html.erb',
              'lib/typingpool/templates/assignment/partials/labeling.html.erb',
              'lib/typingpool/templates/assignment/partials/length-description.html.erb',
              'lib/typingpool/templates/assignment/partials/voices.html.erb',
              'lib/typingpool/templates/assignment/speech.html.erb',
              'lib/typingpool/templates/config.yml',
              'lib/typingpool/templates/project/audio/chunks/.empty_directory',
              'lib/typingpool/templates/project/audio/originals/.empty_directory',
              'lib/typingpool/templates/project/data/.empty_directory',
              'lib/typingpool/templates/project/etc/ About these files - read me.txt',
              'lib/typingpool/templates/project/etc/audio-compat.js',
              'lib/typingpool/templates/project/etc/player/audio-player.js',
              'lib/typingpool/templates/project/etc/player/license.txt',
              'lib/typingpool/templates/project/etc/player/player.swf',
              'lib/typingpool/templates/project/etc/transcript.css',
              'lib/typingpool/templates/transcript.html.erb',
              'lib/typingpool/test/fixtures/amazon-question-html.html',
              'lib/typingpool/test/fixtures/amazon-question-url.txt',
              'lib/typingpool/test/fixtures/audio/mp3/interview.1.mp3',
              'lib/typingpool/test/fixtures/audio/mp3/interview.2.mp3',
              'lib/typingpool/test/fixtures/audio/wma/VN620007.WMA',
              'lib/typingpool/test/fixtures/audio/wma/VN620052.WMA',
              'lib/typingpool/test/fixtures/config-1',
              'lib/typingpool/test/fixtures/config-2',
              'lib/typingpool/test/fixtures/not_yaml.txt',
              'lib/typingpool/test/fixtures/template-2.html.erb',
              'lib/typingpool/test/fixtures/template-3.html.erb',
              'lib/typingpool/test/fixtures/template.html.erb',
              'lib/typingpool/test/fixtures/tp_collect_id.txt',
              'lib/typingpool/test/fixtures/tp_collect_sandbox-assignment.csv',
              'lib/typingpool/test/fixtures/tp_review_id.txt',
              'lib/typingpool/test/fixtures/tp_review_sandbox-assignment.csv',
              'lib/typingpool/test/fixtures/transcript-chunks.csv',
              'lib/typingpool/test/fixtures/vcr/tp-collect-1.yml',
              'lib/typingpool/test/fixtures/vcr/tp-collect-2.yml',
              'lib/typingpool/test/fixtures/vcr/tp-collect-3.yml',
              'lib/typingpool/test/fixtures/vcr/tp-review-1.yml',
              'lib/typingpool/test/fixtures/vcr/tp-review-2.yml',
              'test/make_amazon_question_fixture.rb',
              'test/make_tp_collect_fixture_1.rb',
              'test/make_tp_collect_fixture_2.rb',
              'test/make_tp_collect_fixture_3.rb',
              'test/make_tp_collect_fixture_4.rb',
              'test/make_tp_review_fixture_1.rb',
              'test/make_tp_review_fixture_2.rb',
              'test/make_transcript_chunks_fixture.rb',
              'test/test_integration_script_1_tp_config.rb',
              'test/test_integration_script_2_tp_make.rb',
              'test/test_integration_script_3_tp_assign.rb',
              'test/test_integration_script_4_tp_review.rb',
              'test/test_integration_script_5_tp_collect.rb',
              'test/test_integration_script_6_tp_finish.rb',
              'test/test_unit_amazon.rb',
              'test/test_unit_config.rb',
              'test/test_unit_filer.rb',
              'test/test_unit_project.rb',
              'test/test_unit_project_local.rb',
              'test/test_unit_project_remote.rb',
              'test/test_unit_template.rb',
              'test/test_unit_transcript.rb'
             ]
 end