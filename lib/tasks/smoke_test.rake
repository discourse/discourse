desc "run phantomjs based smoke tests on current build"
task "smoke:test" => :environment do

  phantom_path = File.expand_path('~/phantomjs/bin/phantomjs') 
  phantom_path = nil unless File.exists?(phantom_path)
  phantom_path = phantom_path || 'phantomjs'

  url = ENV["URL"] || Discourse.base_url
  puts "Testing: #{url}"
  results = `#{phantom_path} #{Rails.root}/spec/phantom_js/smoke_test.js #{url}`

  puts results
  if results !~ /ALL PASSED/
    raise "FAILED"
  end
end
