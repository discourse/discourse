# frozen_string_literal: true

class TemporaryDb
  PG_TEMP_PATH = "/tmp/pg_schema_tmp"
  PG_CONF = "#{PG_TEMP_PATH}/postgresql.conf".freeze
  PG_SOCK_PATH = "#{PG_TEMP_PATH}/sockets".freeze

  def port_available?(port)
    TCPServer.open(port).close
    true
  rescue Errno::EADDRINUSE
    false
  end

  def pg_bin_path
    return @pg_bin_path if @pg_bin_path

    %w[13 12 11 10].each do |v|
      bin_path = "/usr/lib/postgresql/#{v}/bin"
      if File.exist?("#{bin_path}/pg_ctl")
        @pg_bin_path = bin_path
        break
      end
    end
    if !@pg_bin_path
      bin_path = "/Applications/Postgres.app/Contents/Versions/latest/bin"
      @pg_bin_path = bin_path if File.exist?("#{bin_path}/pg_ctl")
    end
    if !@pg_bin_path
      puts "Can not find postgres bin path"
      exit 1
    end
    @pg_bin_path
  end

  def initdb_path
    return @initdb_path if @initdb_path

    @initdb_path = `which initdb 2> /dev/null`.strip
    @initdb_path = "#{pg_bin_path}/initdb" if @initdb_path.length == 0

    @initdb_path
  end

  def find_free_port(range)
    range.each { |port| return port if port_available?(port) }
  end

  def pg_port
    @pg_port ||= find_free_port(11_000..11_900)
  end

  def pg_ctl_path
    return @pg_ctl_path if @pg_ctl_path

    @pg_ctl_path = `which pg_ctl 2> /dev/null`.strip
    @pg_ctl_path = "#{pg_bin_path}/pg_ctl" if @pg_ctl_path.length == 0

    @pg_ctl_path
  end

  def start
    FileUtils.rm_rf PG_TEMP_PATH
    `#{initdb_path} -D '#{PG_TEMP_PATH}' --auth-host=trust --locale=en_US.UTF-8 -E UTF8 2> /dev/null`

    FileUtils.mkdir PG_SOCK_PATH
    conf = File.read(PG_CONF)
    File.write(PG_CONF, conf + "\nport = #{pg_port}\nunix_socket_directories = '#{PG_SOCK_PATH}'")

    puts "Starting postgres on port: #{pg_port}"
    ENV["DISCOURSE_PG_PORT"] = pg_port.to_s

    Thread.new { `#{pg_ctl_path} -D '#{PG_TEMP_PATH}' start` }

    puts "Waiting for PG server to start..."
    sleep 0.1 while !`#{pg_ctl_path} -D '#{PG_TEMP_PATH}' status`.include?("server is running")
    @started = true

    `createuser -h localhost -p #{pg_port} -s -D -w discourse 2> /dev/null`
    `createdb -h localhost -p #{pg_port} discourse`

    puts "PG server is ready and DB is loaded"
  end

  def stop
    @started = false
    `#{pg_ctl_path} -D '#{PG_TEMP_PATH}' stop`
  end

  def with_env(&block)
    old_host = ENV["PGHOST"]
    old_user = ENV["PGUSER"]
    old_port = ENV["PGPORT"]
    old_dev_db = ENV["DISCOURSE_DEV_DB"]
    old_rails_db = ENV["RAILS_DB"]

    ENV["PGHOST"] = "localhost"
    ENV["PGUSER"] = "discourse"
    ENV["PGPORT"] = pg_port.to_s
    ENV["DISCOURSE_DEV_DB"] = "discourse"
    ENV["RAILS_DB"] = "discourse"

    yield
  ensure
    ENV["PGHOST"] = old_host
    ENV["PGUSER"] = old_user
    ENV["PGPORT"] = old_port
    ENV["DISCOURSE_DEV_DB"] = old_dev_db
    ENV["RAILS_DB"] = old_rails_db
  end

  def remove
    raise "Error: the database must be stopped before it can be removed" if @started
    FileUtils.rm_rf PG_TEMP_PATH
  end

  def migrate
    raise "Error: the database must be started before it can be migrated." if !@started
    ActiveRecord::Base.establish_connection(
      adapter: "postgresql",
      database: "discourse",
      port: pg_port,
      host: "localhost",
    )

    puts "Running migrations on blank database!"

    old_stdout = $stdout.clone
    old_stderr = $stderr.clone
    $stdout.reopen(File.new("/dev/null", "w"))
    $stderr.reopen(File.new("/dev/null", "w"))

    SeedFu.quiet = true
    Rake::Task["db:migrate"].invoke
  ensure
    $stdout.reopen(old_stdout) if old_stdout
    $stderr.reopen(old_stderr) if old_stderr
  end
end
