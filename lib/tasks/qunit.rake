desc "Runs the qunit test suite"

task "qunit:test", [:timeout] => :environment do |_, args|

  require "rack"
  require "socket"

  unless %x{which phantomjs > /dev/null 2>&1}
    abort "PhantomJS is not installed. Download from http://phantomjs.org"
  end

  # ensure we have this port available
  def port_available? port
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

  unless pid = fork
    Discourse.after_fork
    Rack::Server.start(:config => "config.ru",
                       :AccessLog => [],
                       :Port => port)
    exit
  end

  begin
    success = true
    test_path = "#{Rails.root}/vendor/assets/javascripts"
    cmd = "phantomjs #{test_path}/run-qunit.js http://localhost:#{port}/qunit"

    options = {}

    %w{module filter}.each do |arg|
      options[arg] = ENV[arg.upcase] if ENV[arg.upcase].present?
    end

    if options.present?
      cmd += "?#{options.to_query.gsub('+', '%20')}"
    end

    if args[:timeout].present?
      cmd += " #{args[:timeout]}"
    end

    # wait for server to respond, will exception out on failure
    tries = 0
    begin
      sh(cmd)
    rescue
      exit if ENV['RETRY'].present? && ENV['RETRY'] == 'false'
      sleep 2
      tries += 1
      retry unless tries == 3
    end

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
