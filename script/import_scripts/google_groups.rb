#!/usr/bin/env ruby

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  gem "net-http-persistent"
  gem "nokogiri"
  gem "selenium-webdriver"
end

require "fileutils"
require "nokogiri"
require "optparse"
require "selenium-webdriver"
require 'selenium/webdriver/remote/http/persistent'
require "set"
require "yaml"

DEFAULT_OUTPUT_PATH = "/shared/import/data"

def driver
  @driver ||= begin
    chrome_args = ["headless", "disable-gpu"]
    chrome_args << "no-sandbox" << "disable-dev-shm-usage" if inside_container?
    options = Selenium::WebDriver::Chrome::Options.new(args: chrome_args)
    http_client = Selenium::WebDriver::Remote::Http::Persistent.new
    Selenium::WebDriver.for(:chrome, options: options, http_client: http_client)
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
  rescue Net::ReadTimeout, Selenium::WebDriver::Error::ElementNotVisibleError
    sleep retries
    retry if (retries += 1) < MAX_FIND_RETRIES
  end
end

def crawl_categories
  1.step(nil, 100).each do |start|
    url = "https://groups.google.com/forum/?_escaped_fragment_=categories/#{@groupname}[#{start}-#{start + 99}]"
    get(url)

    topic_urls = extract(".subject a[href*='#{@groupname}']") { |a| a["href"].sub("/d/topic/", "/forum/?_escaped_fragment_=topic/") }
    break if topic_urls.size == 0

    topic_urls.each { |topic_url| crawl_topic(topic_url) }
  end
end

def crawl_topic(url)
  if @scraped_topic_urls.include?(url)
    puts "Skipping #{url}"
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
  puts "Failed to scrape topic at #{url}"
  raise
end

def crawl_message(url, might_be_deleted)
  get(url)

  filename = File.join(@path, "#{url[/#{@groupname}\/(.+)/, 1].sub("/", "-")}.eml")
  content = find("pre")["innerText"]

  if !@first_message_checked
    @first_message_checked = true

    if content.match?(/From:.*\.\.\.@.*/i) && !@force_import
      exit_with_error(<<~MSG)
        It looks like you do not have permissions to see email addresses. Aborting.
        Use the --force option to import anyway.
      MSG
    end
  end

  File.write(filename, content)
rescue Selenium::WebDriver::Error::NoSuchElementError
  raise unless might_be_deleted
  puts "Message might be deleted. Skipping #{url}"
rescue
  puts "Failed to scrape message at #{url}"
  raise
end

def login
  puts "Logging in..."
  get("https://www.google.com/accounts/Login")

  sleep(1)
  email_element = wait_for_element("input[type='email']")
  exit_with_error("Failed to detect 'email' input on login page") if !email_element

  driver.action.move_to(email_element)
  email_element.send_keys(@email)
  email_element.send_keys("\n")

  sleep(1)
  password_element = wait_for_element("input[type='password']")
  exit_with_error("Failed to detect 'password' input on login page") if !password_element

  driver.action.move_to(password_element)
  password_element.send_keys(@password)
  password_element.send_keys("\n")

  sleep(1)

  if driver.current_url.include?("challenge")
    puts "", "2-Step Verification is required."
    puts "Unlock on your phone and press Enter"
    puts "or enter the code from your authenticator app"
    puts "or enter the code you received via SMS (without the G- prefix)"

    print "Enter code: "

    code = gets.chomp

    if code.empty?
      # Verification via phone?
      begin
        wait_for_url { |url| !url.include?("challenge") }
      rescue Selenium::WebDriver::Error::TimeOutError
        exit_with_error("Failed to login. Did you tap 'Yes' on your phone to allow the login?")
      end
    else
      code_element = wait_for_element("input[type='tel']")
      exit_with_error("Failed to detect 'code' input on login page") if !code_element

      code_element.send_keys(code)
      code_element.send_keys("\n")

      begin
        wait_for_url { |url| !url.include?("challenge") }
      rescue Selenium::WebDriver::Error::TimeOutError
        exit_with_error("Failed to login. Wrong code?")
      end
    end
  end

  sleep(1)
  user_element = wait_for_element("a[aria-label*='#{@email}']")
  exit_with_error("Failed to login") if !user_element
end

def wait_for_url
  wait = Selenium::WebDriver::Wait.new(timeout: 5)
  wait.until { yield(driver.current_url) }
end

def wait_for_element(css)
  wait = Selenium::WebDriver::Wait.new(timeout: 5)
  wait.until { driver.find_element(css: css).displayed? }
  find(css)
rescue Selenium::WebDriver::Error::TimeOutError
  nil
end

def exit_with_error(message)
  puts driver.current_url
  STDERR.puts message
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

  @force_import = false

  parser = OptionParser.new do |opts|
    opts.banner = "Usage: google_groups.rb [options]"

    opts.on("-e", "--email EMAIL", "email address of group admin or manager") { |v| @email = v }
    opts.on("-p", "--password PASSWORD", "password of group admin or manager") { |v| @password = v }
    opts.on("-g", "--groupname GROUPNAME") { |v| @groupname = v }
    opts.on("--path PATH", "output path for emails") { |v| @path = v }
    opts.on("-f", "--force", "force import when user isn't allowed to see email addresses") { @force_import = true }
    opts.on("-h", "--help") do
      puts opts
      exit
    end
  end

  begin
    parser.parse!
  rescue OptionParser::ParseError => e
    STDERR.puts e.message, "", parser
    exit 1
  end

  mandatory = [:email, :password, :groupname]
  missing = mandatory.select { |name| instance_variable_get("@#{name}").nil? }

  if missing.any?
    STDERR.puts "Missing arguments: #{missing.join(', ')}", "", parser
    exit 1
  end

  @path = File.join(DEFAULT_OUTPUT_PATH, @groupname) if @path.nil?
  FileUtils.mkpath(@path)
end

parse_arguments
crawl
