# frozen_string_literal: true

require "open-uri"
require "net/http"

def request(path, method: :get, data: nil, return_response: false)
  uri = URI("#{ENV["URL"]}/#{path}")

  req = Object.const_get("Net::HTTP::#{method.capitalize}").new(uri)
  req["Api-Key"] = ENV["DISCOURSE_API_KEY"] ||
    "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  req["Api-Username"] = ENV["DISCOURSE_API_USERNAME"] || "smoke_user"
  if data.present?
    req.body = data.to_json
    req.content_type = "application/json"
  end

  response =
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.request(req)
    end

  return response if return_response

  # There is a high chance of hitting rate limits in the smoke test when
  # creating topics and replies
  if response.code == "429"
    wait_seconds = JSON.parse(response.body)&.[]("extras")&.[]("wait_seconds")&.to_i
    wait_seconds ||= 10

    puts "WAITING: Retrying after rate limit... sleeping #{wait_seconds} seconds"
    sleep wait_seconds

    response =
      Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(req)
      end
  end

  if response.code != "200"
    raise "ERROR: #{path} returned #{response.code}: #{response.body}"
  else
    JSON.parse(response.body)
  end
end

desc "run quick smoke tests on current build"
task "smoke:quick" do
  if ENV["URL"].blank?
    require "#{Rails.root}/config/environment"
    ENV["URL"] = Discourse.base_url
  end

  def test(desc)
    begin
      passed = yield
    rescue => e
    end

    if passed
      puts "PASSED: #{desc}"
    else
      puts "FAILED: #{desc}"
    end

    passed
  end

  # First, check if the server is up or wait for it

  puts "Testing: #{ENV["URL"]}"

  wait = ENV["WAIT_FOR_URL"].to_i
  success = false
  code = "(no error code)"
  retries = 0

  loop do
    begin
      response = request("/srv/status", return_response: true)
      success = response.body == "ok"
      code = response.code
    rescue StandardError
    end

    if !success && wait > 0
      sleep 5
      wait -= 5
      retries += 1
    else
      break
    end
  end

  raise "TRIVIAL GET FAILED WITH #{code}: retried #{retries} times" if !success

  # Then proceed with actual functionality tests

  success &=
    test "/latest.json returns a topic list" do
      @latest_topics = request("latest.json")
      @latest_topics["topic_list"]["topics"].length > 0
    end

  success &=
    test "/categories.json returns a category list" do
      categories = request("categories.json")
      categories["category_list"]["categories"].length > 0
    end

  success &=
    test "/t/:topic_id.json returns topic data" do
      topic_id = @latest_topics["topic_list"]["topics"][0]["id"]
      @topic = request("/t/#{topic_id}.json")
      @topic["post_stream"]["posts"].first["cooked"].present?
    end

  success &=
    test "/u/:username.json returns results" do
      username = @topic["post_stream"]["posts"].first["username"]
      user = request("/u/#{username}.json")
      user["user"]["id"].present? && user["user"]["username"] == username
    end

  success &=
    test "/posts.json creates a new topic" do
      time = Time.now.to_i
      @new_topic_post =
        request(
          "/posts.json",
          method: :post,
          data: {
            title: "This is a new topic #{time}",
            raw: "I can write a new topic inside the smoke test! #{time}\n\n",
          },
        )
      @new_topic_post["id"].present?
    end

  success &=
    test "/posts.json creates a reply" do
      reply =
        request(
          "/posts.json",
          method: :post,
          data: {
            topic_id: @new_topic_post["topic_id"],
            raw: "I can even write a reply inside the smoke test ;) #{Time.now.to_i}",
          },
        )
      reply["id"].present?
    end

  success &=
    test "/posts/:id.json updates a post" do
      edited_post =
        request(
          "/posts/#{@new_topic_post["id"]}.json",
          method: :put,
          data: {
            post: {
              raw: "#{@new_topic_post["raw"]}\n\nI edited this post",
            },
          },
        )
      edited_post["post"]["id"].present?
    end

  if success
    puts "ALL PASSED"
  else
    raise "FAILED"
  end
end

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
