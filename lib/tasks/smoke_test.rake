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

  uri = URI(url)
  request = Net::HTTP::Get.new(uri)

  if ENV["AUTH_USER"] && ENV["AUTH_PASSWORD"]
    request.basic_auth(ENV['AUTH_USER'], ENV['AUTH_PASSWORD'])
  end

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
    http.request(request)
  end

  if response.code != "200"
    raise "TRIVIAL GET FAILED WITH #{response.code}"
  end

  results = ""

  command =
    if ENV["USE_CHROME"]
      "node #{Rails.root}/test/smoke_test.js #{url}"
    else
      "#{phantom_path} #{Rails.root}/spec/phantom_js/smoke_test.js #{url}"
    end

  IO.popen(command).each do |line|
    puts line
    results << line
  end

  if results !~ /ALL PASSED/
    raise "FAILED"
  end
end
