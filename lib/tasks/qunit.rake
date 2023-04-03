# frozen_string_literal: true

desc "Runs the qunit test suite"
task "qunit:test", %i[timeout qunit_path filter] do |_, args|
  require "socket"
  require "chrome_installed_checker"

  begin
    ChromeInstalledChecker.run
  rescue ChromeInstalledChecker::ChromeError => err
    abort err.message
  end

  unless system("command -v pnpm >/dev/null;")
    abort "pnpm is not installed. Download from https://pnpm.io/installation"
  end

  report_requests = ENV["REPORT_REQUESTS"] == "1"

  system("pnpm install")

  # ensure we have this port available
  def port_available?(port)
    server = TCPServer.open port
    server.close
    true
  rescue Errno::EADDRINUSE
    false
  end

  if ENV["QUNIT_EMBER_CLI"] == "0"
    puts "The 'legacy' ember environment is discontinued - running tests with ember-cli assets..."
  end

  port = ENV["TEST_SERVER_PORT"] || 60_099
  port += 1 while !port_available? port

  unicorn_port = 60_098
  unicorn_port += 1 while unicorn_port == port || !port_available?(unicorn_port)

  env = {
    "RAILS_ENV" => ENV["QUNIT_RAILS_ENV"] || "test",
    "SKIP_ENFORCE_HOSTNAME" => "1",
    "UNICORN_PID_PATH" => "#{Rails.root}/tmp/pids/unicorn_test_#{unicorn_port}.pid", # So this can run alongside development
    "UNICORN_PORT" => unicorn_port.to_s,
    "UNICORN_SIDEKIQS" => "0",
    "DISCOURSE_SKIP_CSS_WATCHER" => "1",
    "UNICORN_LISTENER" => "127.0.0.1:#{unicorn_port}",
    "LOGSTASH_UNICORN_URI" => nil,
    "UNICORN_WORKERS" => "1",
    "UNICORN_TIMEOUT" => "90",
  }

  pid = Process.spawn(env, "#{Rails.root}/bin/unicorn", pgroup: true)

  begin
    success = true
    test_path = "#{Rails.root}/test"
    qunit_path = args[:qunit_path]
    filter = args[:filter]

    options = { seed: (ENV["QUNIT_SEED"] || Random.new.seed), hidepassed: 1 }

    %w[
      module
      filter
      qunit_skip_core
      qunit_single_plugin
      theme_name
      theme_url
      theme_id
    ].each { |arg| options[arg] = ENV[arg.upcase] if ENV[arg.upcase].present? }

    options["report_requests"] = "1" if report_requests

    query = options.to_query

    @now = Time.now
    def elapsed
      Time.now - @now
    end

    # wait for server to accept connections
    require "net/http"
    warmup_path = "/srv/status"
    uri = URI("http://localhost:#{unicorn_port}/#{warmup_path}")
    puts "Warming up Rails server"

    begin
      Net::HTTP.get(uri)
    rescue Errno::ECONNREFUSED, Errno::EADDRNOTAVAIL, Net::ReadTimeout, EOFError
      sleep 1
      retry if elapsed() <= 60
      puts "Timed out. Can not connect to forked server!"
      exit 1
    end
    puts "Rails server is warmed up"

    cmd = ["env", "UNICORN_PORT=#{unicorn_port}"]

    if qunit_path
      # Bypass `ember test` - it only works properly for the `/tests` path.
      # We have to trigger a `build` manually so that JS is available for rails to serve.
      system("pnpm", "ember", "build", chdir: "#{Rails.root}/app/assets/javascripts/discourse")
      test_page = "#{qunit_path}?#{query}&testem=1"
      cmd += ["pnpm", "testem", "ci", "-f", "testem.js", "-t", test_page]
    else
      cmd += ["pnpm", "ember", "exam", "--query", query]
      if parallel = ENV["QUNIT_PARALLEL"]
        cmd += ["--load-balance", "--parallel", parallel]
      end
      cmd += ["--filter", filter] if filter
    end

    system(*cmd, chdir: "#{Rails.root}/app/assets/javascripts/discourse")

    success &&= $?.success?
  ensure
    # was having issues with HUP
    Process.kill "-KILL", pid
    FileUtils.rm("#{Rails.root}/tmp/pids/unicorn_test_#{unicorn_port}.pid")
  end

  if success
    puts "\nTests Passed"
  else
    puts "\nTests Failed"
    exit(1)
  end
end
