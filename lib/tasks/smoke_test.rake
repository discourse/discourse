desc "run phantomjs based smoke tests on current build"
task "smoke:test" do
  phantom_path = File.expand_path('~/phantomjs/bin/phantomjs')
  phantom_path = nil unless File.exists?(phantom_path)
  phantom_path = phantom_path || 'phantomjs'

  url = ENV["URL"]
  if !url
    require "#{Rails.root}/config/environment"
    url = Discourse.base_url
  end

  puts "Testing: #{url}"

  require 'open-uri'
  require 'net/http'

  res = Net::HTTP.get_response(URI.parse(url))
  if res.code != "200"
    raise "TRIVIAL GET FAILED WITH #{res.code}"
  end

  results = ""
  IO.popen("#{phantom_path} #{Rails.root}/spec/phantom_js/smoke_test.js #{url}").each do |line|
    puts line
    results << line
  end

  if results !~ /ALL PASSED/
    raise "FAILED"
  end
end
