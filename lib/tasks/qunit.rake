desc "Runs the qunit test suite"

task "qunit:test" => :environment do

  require "rack"

  unless %x{which phantomjs > /dev/null 2>&1}
    abort "PhantomJS is not installed. Download from http://phantomjs.org"
  end

  port = ENV['TEST_SERVER_PORT'] || 60099
  server = Thread.new do
    Rack::Server.start(:config => "config.ru",
                       :AccessLog => [],
                       :Port => port)
  end

  begin
    success = true
    test_path = "#{Rails.root}/vendor/assets/javascripts"
    cmd = "phantomjs #{test_path}/run-qunit.js \"http://localhost:#{port}/qunit\""

    rake_system(cmd)

    # A bit of a hack until we can figure this out on Travis
    tries = 0
    while tries < 3 && $?.exitstatus === 124
      tries += 1
      puts "\nTimed Out. Trying again...\n"
      sh(cmd)
    end

    success &&= $?.success?

  ensure
    server.kill
  end

  if success
    puts "\nTests Passed"
  else
    puts "\nTests Failed"
    exit(1)
  end

end