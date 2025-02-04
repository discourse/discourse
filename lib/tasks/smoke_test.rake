# frozen_string_literal: true

desc "run chrome headless smoke tests on current build"
task "smoke:test" do
  require "chrome_installed_checker"

  begin
    ChromeInstalledChecker.run
  rescue ChromeInstalledChecker::ChromeError => err
    abort err.message
  end

  system("pnpm install", exception: true)

  url = ENV["URL"]
  if !url
    require "#{Rails.root}/config/environment"
    url = Discourse.base_url
  end

  puts "Testing: #{url}"

  require "open-uri"
  require "net/http"

  uri = URI(url)
  request = Net::HTTP::Get.new(uri)

  if ENV["AUTH_USER"] && ENV["AUTH_PASSWORD"]
    request.basic_auth(ENV["AUTH_USER"], ENV["AUTH_PASSWORD"])
  end

  dir = ENV["SMOKE_TEST_SCREENSHOT_PATH"] || "tmp/smoke-test-screenshots"
  FileUtils.mkdir_p(dir) unless Dir.exist?(dir)

  wait = ENV["WAIT_FOR_URL"].to_i

  success = false
  code = nil
  retries = 0

  loop do
    response =
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
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

  raise "TRIVIAL GET FAILED WITH #{code}: retried #{retries} times" if !success

  results = +""

  node_arguments = []
  node_arguments << "--inspect-brk" if ENV["DEBUG_NODE"]
  node_arguments << "#{Rails.root}/test/smoke-test.mjs"
  node_arguments << url

  IO
    .popen("node #{node_arguments.join(" ")}")
    .each do |line|
      puts line
      results << line
    end

  raise "FAILED" if results !~ /ALL PASSED/
end
