desc "run chrome headless smoke tests on current build"
task "smoke:test" do
  unless system("command -v google-chrome >/dev/null;")
    abort "Chrome is not installed. Download from https://www.google.com/chrome/browser/desktop/index.html"
  end

  if Gem::Version.new(`$(command -v google-chrome) --version`.match(/[\d\.]+/)[0]) < Gem::Version.new("59")
    abort "Chrome 59 or higher is required to run smoke tests in headless mode."
  end

  system("yarn install --dev")

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

  dir = ENV["SMOKE_TEST_SCREENSHOT_PATH"] || 'tmp/smoke-test-screenshots'
  FileUtils.mkdir_p(dir) unless Dir.exists?(dir)

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
    http.request(request)
  end

  if response.code != "200"
    raise "TRIVIAL GET FAILED WITH #{response.code}"
  end

  results = ""

  IO.popen("node #{Rails.root}/test/smoke_test.js #{url}").each do |line|
    puts line
    results << line
  end

  if results !~ /ALL PASSED/
    raise "FAILED"
  end
end
