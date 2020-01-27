# frozen_string_literal: true

desc "Runs the qunit test suite"

task "qunit:test", [:timeout, :qunit_path] do |_, args|
  require "socket"
  require 'rbconfig'

  if RbConfig::CONFIG['host_os'][/darwin|mac os/]
    google_chrome_cli = "/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome"
  else
    google_chrome_cli = "google-chrome"
  end

  unless system("command -v \"#{google_chrome_cli}\" >/dev/null")
    abort "Chrome is not installed. Download from https://www.google.com/chrome/browser/desktop/index.html"
  end

  if Gem::Version.new(`\"#{google_chrome_cli}\" --version`.match(/[\d\.]+/)[0]) < Gem::Version.new("59")
    abort "Chrome 59 or higher is required to run tests in headless mode."
  end

  unless system("command -v yarn >/dev/null;")
    abort "Yarn is not installed. Download from https://yarnpkg.com/lang/en/docs/install/"
  end

  system("yarn install --dev")

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
      "RAILS_ENV" => "test",
      "SKIP_ENFORCE_HOSTNAME" => "1",
      "UNICORN_PID_PATH" => "#{Rails.root}/tmp/pids/unicorn_test.pid", # So this can run alongside development
      "UNICORN_PORT" => port.to_s,
      "UNICORN_SIDEKIQS" => "0"
    },
    "#{Rails.root}/bin/unicorn -c config/unicorn.conf.rb"
  )

  begin
    success = true
    test_path = "#{Rails.root}/test"
    qunit_path = args[:qunit_path] || "/qunit"
    cmd = "node #{test_path}/run-qunit.js http://localhost:#{port}#{qunit_path}"
    options = { seed: (ENV["QUNIT_SEED"] || Random.new.seed), hidepassed: 1 }

    %w{module filter qunit_skip_core qunit_single_plugin}.each do |arg|
      options[arg] = ENV[arg.upcase] if ENV[arg.upcase].present?
    end

    if options.present?
      cmd += "?#{options.to_query.gsub('+', '%20').gsub("&", '\\\&')}"
    end

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
    rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL, Net::ReadTimeout
      sleep 1
      retry unless elapsed() > 60
      puts "Timed out. Can no connect to forked server!"
      exit 1
    end
    puts "Rails server is warmed up"

    sh(cmd)

    # A bit of a hack until we can figure this out on Travis
    tries = 0
    while tries < 3 && $?.exitstatus == 124
      tries += 1
      puts "\nTimed Out. Trying again...\n"
      sh(cmd)
    end

    success &&= $?.success?

  ensure
    # was having issues with HUP
    Process.kill "KILL", pid
  end

  if success
    puts "\nTests Passed"
  else
    puts "\nTests Failed"
    exit(1)
  end

end
