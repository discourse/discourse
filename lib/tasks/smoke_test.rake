# frozen_string_literal: true

desc "run chrome headless smoke tests on current build"
task "smoke:test" do
  require "chrome_installed_checker"

  begin
    ChromeInstalledChecker.run
  rescue ChromeNotInstalled, ChromeVersionTooLow => err
    abort err.message
  end

  system("yarn install")

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
  FileUtils.mkdir_p(dir) unless Dir.exist?(dir)

  wait = ENV["WAIT_FOR_URL"].to_i

  success = false
  code = nil
  retries = 0

  loop do
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(request)
    end

    success = response.code == "200"
    code = response.code

    if !success && wait > 0
      sleep 5
      wait -= 5
      retries += 1
    else
      break
    end
  end

  if !success
    raise "TRIVIAL GET FAILED WITH #{code}: retried #{retries} times"
  end

  results = +""

  node_arguments = []
  node_arguments << '--inspect-brk' if ENV["DEBUG_NODE"]
  node_arguments << "#{Rails.root}/test/smoke_test.js"
  node_arguments << url

  IO.popen("node #{node_arguments.join(' ')}").each do |line|
    puts line
    results << line
  end

  if results !~ /ALL PASSED/
    raise "FAILED"
  end

  api_key = ENV["ADMIN_API_KEY"]
  api_username = ENV["ADMIN_API_USERNAME"]
  theme_url = ENV["SMOKE_TEST_THEME_URL"]

  next if api_key.blank? && api_username.blank? && theme_url.blank?

  puts "Running QUnit tests for theme #{theme_url.inspect} using API key #{api_key[0..3]}… and username #{api_username.inspect}"

  query_params = {
    seed: Random.new.seed,
    theme_url: theme_url,
    hidepassed: 1,
    report_requests: 1
  }
  url += '/' if !url.end_with?('/')
  full_url = "#{url}theme-qunit?#{query_params.to_query}"
  timeout = 1000 * 60 * 10

  sh(
    "node",
    "#{Rails.root}/test/run-qunit.js",
    full_url,
    timeout.to_s
  )

  if !$?.success?
    raise "THEME TESTS FAILED!"
  end
end
