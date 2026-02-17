# frozen_string_literal: true

require "open3"
require "securerandom"
require "tmpdir"

class TemporaryDb
  PG_TEMP_PREFIX = "pg_schema_tmp"
  VERSIONS = 10..30 # arbitrary upper limit to avoid updating this code for a long time
  STARTUP_TIMEOUT_SECONDS = 60

  def initialize
    @pg_temp_path = File.join(Dir.tmpdir, "#{PG_TEMP_PREFIX}_#{SecureRandom.hex(6)}")
    @pg_conf = "#{@pg_temp_path}/postgresql.conf"
    @pg_sock_path = "#{@pg_temp_path}/sockets"
  end

  def port_available?(port)
    TCPServer.open(port).close
    true
  rescue Errno::EADDRINUSE
    false
  end

  def pg_bin_path
    return @pg_bin_path if @pg_bin_path

    # Try pg_config first (works on any platform if PG dev packages are installed)
    pg_config_bin = `pg_config --bindir 2>/dev/null`.strip
    if pg_config_bin.length > 0 && File.exist?("#{pg_config_bin}/pg_ctl")
      @pg_bin_path = pg_config_bin
      return @pg_bin_path
    end

    # Debian/Ubuntu: /usr/lib/postgresql/{version}/bin
    VERSIONS.reverse_each do |v|
      bin_path = "/usr/lib/postgresql/#{v}/bin"
      if File.exist?("#{bin_path}/pg_ctl")
        @pg_bin_path = bin_path
        return @pg_bin_path
      end
    end

    # RHEL/Fedora (PGDG): /usr/pgsql-{version}/bin
    VERSIONS.reverse_each do |v|
      bin_path = "/usr/pgsql-#{v}/bin"
      if File.exist?("#{bin_path}/pg_ctl")
        @pg_bin_path = bin_path
        return @pg_bin_path
      end
    end

    # macOS Postgres.app
    bin_path = "/Applications/Postgres.app/Contents/Versions/latest/bin"
    if File.exist?("#{bin_path}/pg_ctl")
      @pg_bin_path = bin_path
      return @pg_bin_path
    end

    raise "Cannot find PostgreSQL bin path (pg_ctl). Install PostgreSQL or ensure pg_config is in PATH."
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
    init_data_directory
    configure_ports

    puts "Starting postgres on port: #{pg_port}"
    @previous_discourse_pg_port = ENV["DISCOURSE_PG_PORT"]
    ENV["DISCOURSE_PG_PORT"] = pg_port.to_s

    start_server
    @started = true

    create_user
    create_database

    puts "PG server is ready and DB is loaded"
  rescue StandardError
    restore_discourse_pg_port
    raise
  end

  def stop
    @started = false
    `#{pg_ctl_path} -D '#{@pg_temp_path}' stop`
  ensure
    restore_discourse_pg_port
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
    FileUtils.rm_rf @pg_temp_path
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

  private

  def init_data_directory
    FileUtils.rm_rf @pg_temp_path
    run_command!(
      initdb_path,
      "-D",
      @pg_temp_path,
      "--auth-host=trust",
      "--locale=en_US.UTF-8",
      "-E",
      "UTF8",
      error_prefix: "Failed to initialize postgres data directory",
    )
  end

  def configure_ports
    FileUtils.mkdir(@pg_sock_path)
    conf = File.read(@pg_conf)
    File.write(@pg_conf, conf + "\nport = #{pg_port}\nunix_socket_directories = '#{@pg_sock_path}'")
  end

  def start_server
    run_command!(
      pg_ctl_path,
      "-D",
      @pg_temp_path,
      "-w",
      "-t",
      STARTUP_TIMEOUT_SECONDS.to_s,
      "start",
      error_prefix: "Failed to start postgres within #{STARTUP_TIMEOUT_SECONDS}s",
    )
  end

  def create_user
    run_command!(
      "createuser",
      "-h",
      "localhost",
      "-p",
      pg_port.to_s,
      "-s",
      "-D",
      "-w",
      "discourse",
      error_prefix: "Failed to create temporary postgres superuser",
    )
  end

  def create_database
    run_command!(
      "createdb",
      "-h",
      "localhost",
      "-p",
      pg_port.to_s,
      "discourse",
      error_prefix: "Failed to create temporary postgres database",
    )
  end

  def run_command!(*args, error_prefix:)
    stdout, stderr, status = Open3.capture3(*args)
    return if status.success?

    details = stderr.to_s.strip
    details = stdout.to_s.strip if details.empty?
    details = "unknown error" if details.empty?
    raise "#{error_prefix}: #{details}"
  rescue Errno::ENOENT => e
    raise "#{error_prefix}: #{e.message}"
  end

  def restore_discourse_pg_port
    ENV["DISCOURSE_PG_PORT"] = @previous_discourse_pg_port
    @previous_discourse_pg_port = nil
  end
end
