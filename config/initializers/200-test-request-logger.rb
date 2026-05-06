# frozen_string_literal: true

# Diagnostic only. Mounted as the outermost middleware when LOG_TEST_REQUESTS=1.
# Logs request start/end with in-flight count, PID, and wall-clock duration so
# we can tell whether QUnit chunk-fetch hangs are caused by Rails worker
# starvation, slow handlers, or something further downstream.
if ENV["LOG_TEST_REQUESTS"] == "1"
  class TestRequestLogger
    @@in_flight = Concurrent::AtomicFixnum.new(0)

    def initialize(app)
      @app = app
    end

    def call(env)
      n = @@in_flight.increment
      path = env["PATH_INFO"]
      method = env["REQUEST_METHOD"]
      pid = Process.pid
      t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      log("[req-start] in_flight=#{n} pid=#{pid} #{method} #{path}")
      status, headers, body = @app.call(env)
      t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      log(
        "[req-end]   in_flight=#{@@in_flight.value} pid=#{pid} dt=#{((t1 - t0) * 1000).to_i}ms #{status} #{path}",
      )
      [status, headers, body]
    ensure
      @@in_flight.decrement
    end

    private

    # bin/qunit redirects spawned-Rails-server stdio to tmp/test_server_<port>.log,
    # which the workflow tails. Rails.logger.* goes to log/test.log instead, so
    # write to STDERR to land in the file we're actually capturing in CI.
    def log(line)
      $stderr.puts(line)
      $stderr.flush
    end
  end

  Rails.application.config.middleware.insert_before(0, TestRequestLogger)
end
