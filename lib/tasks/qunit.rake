# frozen_string_literal: true

desc "Runs the qunit test suite"

task "qunit:test", [:timeout, :qunit_path] do |_, args|
  require "socket"
  require "chrome_installed_checker"

  begin
    ChromeInstalledChecker.run
  rescue ChromeNotInstalled, ChromeVersionTooLow => err
    abort err.message
  end

  unless system("command -v yarn >/dev/null;")
    abort "Yarn is not installed. Download from https://yarnpkg.com/lang/en/docs/install/"
  end

  report_requests = ENV['REPORT_REQUESTS'] == "1"

  system("yarn install")

  # ensure we have this port available
  def port_available?(port)
    server = TCPServer.open port
    server.close
    true
  rescue Errno::EADDRINUSE
    false
  end

  port = ENV['TEST_SERVER_PORT'] || 60099

  while !port_available? port
    port += 1
  end

  pid = Process.spawn(
    {
      "RAILS_ENV" => ENV["QUNIT_RAILS_ENV"] || "test",
      "SKIP_ENFORCE_HOSTNAME" => "1",
      "UNICORN_PID_PATH" => "#{Rails.root}/tmp/pids/unicorn_test_#{port}.pid", # So this can run alongside development
      "UNICORN_PORT" => port.to_s,
      "UNICORN_SIDEKIQS" => "0",
      "DISCOURSE_SKIP_CSS_WATCHER" => "1",
      "UNICORN_LISTENER" => "127.0.0.1:#{port}",
      "LOGSTASH_UNICORN_URI" => nil,
      "UNICORN_WORKERS" => "3"
    },
    "#{Rails.root}/bin/unicorn -c config/unicorn.conf.rb",
    pgroup: true
  )

  begin
    success = true
    test_path = "#{Rails.root}/test"
    qunit_path = args[:qunit_path] || "/qunit"
    cmd = "node #{test_path}/run-qunit.js http://localhost:#{port}#{qunit_path}"
    options = { seed: (ENV["QUNIT_SEED"] || Random.new.seed), hidepassed: 1 }

    %w{module filter qunit_skip_core qunit_single_plugin theme_name theme_url theme_id}.each do |arg|
      options[arg] = ENV[arg.upcase] if ENV[arg.upcase].present?
    end

    if report_requests
      options['report_requests'] = '1'
    end

    cmd += "?#{options.to_query.gsub('+', '%20').gsub("&", '\\\&')}"

    if args[:timeout].present?
      cmd += " #{args[:timeout]}"
    end

    @now = Time.now
    def elapsed
      Time.now - @now
    end

    # wait for server to accept connections
    require 'net/http'
    uri = URI("http://localhost:#{port}/assets/test_helper.js")
    puts "Warming up Rails server"
    begin
      Net::HTTP.get(uri)
    rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL, Net::ReadTimeout, EOFError
      sleep 1
      retry unless elapsed() > 60
      puts "Timed out. Can not connect to forked server!"
      exit 1
    end
    puts "Rails server is warmed up"

    sh(cmd)
    success &&= $?.success?
  ensure
    # was having issues with HUP
    Process.kill "-KILL", pid
    FileUtils.rm("#{Rails.root}/tmp/pids/unicorn_test_#{port}.pid")
  end

  if success
    puts "\nTests Passed"
  else
    puts "\nTests Failed"
    exit(1)
  end

end
