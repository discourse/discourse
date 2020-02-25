#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  gem "webdrivers"
  gem "colored2"
end

require "fileutils"
require "optparse"
require "set"
require "yaml"

DEFAULT_OUTPUT_PATH = "/shared/import/data"
DEFAULT_COOKIES_TXT = "/shared/import/cookies.txt"

def driver
  @driver ||= begin
    chrome_args = ["disable-gpu"]
    chrome_args << "headless" unless ENV["NOT_HEADLESS"] == '1'
    chrome_args << "no-sandbox" if inside_container?
    options = Selenium::WebDriver::Chrome::Options.new(args: chrome_args)
    Selenium::WebDriver.for(:chrome, options: options)
  end
end

def inside_container?
  File.foreach("/proc/1/cgroup") do |line|
    return true if line.include?("docker")
  end

  false
end

MAX_GET_RETRIES = 5
MAX_FIND_RETRIES = 3

def get(url)
  begin
    retries ||= 0
    driver.get(url)
  rescue Net::ReadTimeout
    sleep retries
    retry if (retries += 1) < MAX_GET_RETRIES
  end
end

def extract(css, parent_element = driver)
  begin
    retries ||= 0
    parent_element.find_elements(css: css).map { |element| yield(element) }
  rescue Net::ReadTimeout, Selenium::WebDriver::Error::StaleElementReferenceError
    sleep retries
    retry if (retries += 1) < MAX_FIND_RETRIES
  end
end

def find(css, parent_element = driver)
  begin
    retries ||= 0
    parent_element.find_element(css: css)
  rescue Net::ReadTimeout, Selenium::WebDriver::Error::ElementNotInteractableError
    sleep retries
    retry if (retries += 1) < MAX_FIND_RETRIES
  end
end

def base_url
  if @domain.nil?
    "https://groups.google.com/forum/?_escaped_fragment_=categories"
  else
    "https://groups.google.com/a/#{@domain}/forum/?_escaped_fragment_=categories"
  end
end

def crawl_categories
  1.step(nil, 100).each do |start|
    url = "#{base_url}/#{@groupname}[#{start}-#{start + 99}]"
    get(url)

    begin
      if start == 1 && find("h2").text == "Error 403"
        exit_with_error(<<~MSG.red.bold)
          Unable to find topics. Try running the script with the "--domain example.com"
          option if you are a G Suite user and your group's URL contains a path with
          your domain that looks like "/a/example.com".
        MSG
      end
    rescue Selenium::WebDriver::Error::NoSuchElementError
      # Ignore this error. It simply means there wasn't an error.
    end

    topic_urls = extract(".subject a[href*='#{@groupname}']") { |a| a["href"].sub("/d/topic/", "/forum/?_escaped_fragment_=topic/") }
    break if topic_urls.size == 0

    topic_urls.each { |topic_url| crawl_topic(topic_url) }
  end
end

def crawl_topic(url)
  if @scraped_topic_urls.include?(url)
    puts "Skipping".green << " #{url}"
    return
  end

  puts "Scraping #{url}"
  get(url)

  extract(".subject a[href*='#{@groupname}']") do |a|
    [
      a["href"].sub("/d/msg/", "/forum/message/raw?msg="),
      a["title"].empty?
    ]
  end.each { |msg_url, might_be_deleted| crawl_message(msg_url, might_be_deleted) }

  @scraped_topic_urls << url
rescue
  puts "Failed to scrape topic at #{url}".red
  raise if @abort_on_error
end

def crawl_message(url, might_be_deleted)
  get(url)

  filename = File.join(@path, "#{url[/#{@groupname}\/(.+)/, 1].sub("/", "-")}.eml")
  content = find("pre")["innerText"]

  if !@first_message_checked
    @first_message_checked = true

    if content.match?(/From:.*\.\.\.@.*/i) && !@force_import
      exit_with_error(<<~MSG.red.bold)
        It looks like you do not have permissions to see email addresses. Aborting.
        Use the --force option to import anyway.
      MSG
    end
  end

  File.write(filename, content)
rescue Selenium::WebDriver::Error::NoSuchElementError
  if might_be_deleted
    puts "Message might be deleted. Skipping #{url}"
  else
    puts "Failed to scrape message at #{url}".red
    raise if @abort_on_error
  end
rescue
  puts "Failed to scrape message at #{url}".red
  raise if @abort_on_error
end

def login
  puts "Logging in..."
  get("https://google.com/404")

  add_cookies(
    "accounts.google.com",
    "myaccount.google.com",
    "google.com"
  )

  get("https://accounts.google.com/servicelogin")

  begin
    wait_for_url { |url| url.start_with?("https://myaccount.google.com") }
  rescue Selenium::WebDriver::Error::TimeoutError
    exit_with_error("Failed to login. Please check the content of your cookies.txt".red.bold)
  end
end

def add_cookies(*domains)
  File.readlines(@cookies).each do |line|
    parts = line.chomp.split("\t")
    next if parts.size != 7 || !domains.any? { |domain| parts[0] =~ /^\.?#{Regexp.escape(domain)}$/ }

    driver.manage.add_cookie(
      domain: parts[0],
      httpOnly: "true".casecmp?(parts[1]),
      path: parts[2],
      secure: "true".casecmp?(parts[3]),
      expires: parts[4] == "0" ? nil : DateTime.strptime(parts[4], "%s"),
      name: parts[5],
      value: parts[6]
    )
  end
end

def wait_for_url
  wait = Selenium::WebDriver::Wait.new(timeout: 5)
  wait.until { yield(driver.current_url) }
end

def exit_with_error(*messages)
  STDERR.puts messages
  exit 1
end

def crawl
  start_time = Time.now
  status_filename = File.join(@path, "status.yml")
  @scraped_topic_urls = File.exists?(status_filename) ? YAML.load_file(status_filename) : Set.new

  login

  begin
    crawl_categories
  ensure
    File.write(status_filename, @scraped_topic_urls.to_yaml)
  end

  elapsed = Time.now - start_time
  puts "", "", "Done (%02dh %02dmin %02dsec)" % [elapsed / 3600, elapsed / 60 % 60, elapsed % 60]
end

def parse_arguments
  puts ""

  # default values
  @force_import = false
  @abort_on_error = false
  @cookies = DEFAULT_COOKIES_TXT if File.exist?(DEFAULT_COOKIES_TXT)

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: google_groups.rb [options]"

    opts.on("-g", "--groupname GROUPNAME") { |v| @groupname = v }
    opts.on("-d", "--domain DOMAIN") { |v| @domain = v }
    opts.on("-c", "--cookies PATH", "path to cookies.txt") { |v| @cookies = v }
    opts.on("--path PATH", "output path for emails") { |v| @path = v }
    opts.on("-f", "--force", "force import when user isn't allowed to see email addresses") { @force_import = true }
    opts.on("-a", "--abort-on-error", "abort crawl on error instead of skipping message") { @abort_on_error = true }
    opts.on("-h", "--help") do
      puts opts
      exit
    end
  end

  begin
    parser.parse!
  rescue OptionParser::ParseError => e
    exit_with_error(e.message, "", parser)
  end

  mandatory = [:groupname, :cookies]
  missing = mandatory.select { |name| instance_variable_get("@#{name}").nil? }

  exit_with_error("Missing arguments: #{missing.join(', ')}".red.bold, "", parser, "") if missing.any?
  exit_with_error("cookies.txt not found at #{@cookies}".red.bold, "") if !File.exist?(@cookies)

  @path = File.join(DEFAULT_OUTPUT_PATH, @groupname) if @path.nil?
  FileUtils.mkpath(@path)
end

parse_arguments
crawl
