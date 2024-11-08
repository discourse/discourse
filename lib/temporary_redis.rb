# frozen_string_literal: true

class TemporaryRedis
  REDIS_TEMP_DIR = "/tmp/discourse_temp_redis"
  REDIS_LOG_PATH = "#{REDIS_TEMP_DIR}/redis.log".freeze
  REDIS_PID_PATH = "#{REDIS_TEMP_DIR}/redis.pid".freeze

  attr_reader :instance

  def initialize
    set_redis_server_bin
  end

  def port
    @port ||= find_free_port(11_000..11_900)
  end

  def start
    return if @started
    FileUtils.rm_rf(REDIS_TEMP_DIR)
    Dir.mkdir(REDIS_TEMP_DIR)
    FileUtils.touch(REDIS_LOG_PATH)

    puts "Starting redis on port: #{port}"
    @thread =
      Thread.new do
        system(
          @redis_server_bin,
          "--port",
          port.to_s,
          "--pidfile",
          REDIS_PID_PATH,
          "--logfile",
          REDIS_LOG_PATH,
          "--databases",
          "1",
          "--save",
          '""',
          "--appendonly",
          "no",
          "--daemonize",
          "no",
          "--maxclients",
          "100",
          "--dir",
          REDIS_TEMP_DIR,
        )
      end

    puts "Waiting for redis server to start..."
    success = false
    instance = nil
    config = { port: port, host: "127.0.0.1", db: 0 }
    start = Time.now
    while !success
      begin
        instance = DiscourseRedis.new(config, namespace: true)
        success = instance.ping == "PONG"
      rescue Redis::CannotConnectError
      ensure
        if !success && (Time.now - start) >= 5
          STDERR.puts "ERROR: Could not connect to redis in 5 seconds."
          self.remove
          exit(1)
        elsif !success
          sleep 0.1
        end
      end
    end
    puts "Redis is ready"
    @instance = instance
    @started = true
  end

  def remove
    if @instance
      @instance.shutdown
      @thread.join
      puts "Redis has been shutdown."
    end
    FileUtils.rm_rf(REDIS_TEMP_DIR)
    @started = false
    puts "Redis files have been cleaned up."
  end

  private

  def set_redis_server_bin
    path = `which redis-server 2> /dev/null`.strip
    if path.size < 1
      STDERR.puts "ERROR: redis-server is not installed on this machine. Please install it"
      exit(1)
    end
    @redis_server_bin = path
  rescue => ex
    STDERR.puts "ERROR: Failed to find redis-server binary:"
    STDERR.puts ex.inspect
    exit(1)
  end

  def find_free_port(range)
    range.each { |port| return port if port_available?(port) }
  end

  def port_available?(port)
    TCPServer.open(port).close
    true
  rescue Errno::EADDRINUSE
    false
  end
end
