# frozen_string_literal: true

require "open3"
require "securerandom"
require "tmpdir"

class TemporaryDb
  PG_TEMP_PREFIX = "pg_schema_tmp"
  VERSIONS = 10..30 # arbitrary upper limit to avoid updating this code for a long time
  STARTUP_TIMEOUT_SECONDS = 60
  DEFAULT_PG_SYSTEM_USER = "postgres"

  def initialize(pg_system_user: DEFAULT_PG_SYSTEM_USER, versions: VERSIONS)
    @pg_temp_path = File.join(Dir.tmpdir, "#{PG_TEMP_PREFIX}_#{SecureRandom.hex(6)}")
    @pg_conf = "#{@pg_temp_path}/postgresql.conf"
    @pg_sock_path = "#{@pg_temp_path}/sockets"
    @pg_system_user = pg_system_user
    @versions = versions
  end

  def port_available?(port)
    TCPServer.open(port).close
    true
  rescue Errno::EADDRINUSE
    false
  end

  def pg_bin_path
    return @pg_bin_path if @pg_bin_path

    # Debian/Ubuntu: /usr/lib/postgresql/{version}/bin
    @versions.reverse_each do |v|
      bin_path = "/usr/lib/postgresql/#{v}/bin"
      return @pg_bin_path = bin_path if File.exist?("#{bin_path}/pg_ctl")
    end

    # RHEL/Fedora (PGDG): /usr/pgsql-{version}/bin
    @versions.reverse_each do |v|
      bin_path = "/usr/pgsql-#{v}/bin"
      return @pg_bin_path = bin_path if File.exist?("#{bin_path}/pg_ctl")
    end

    # macOS Postgres.app: /Applications/Postgres.app/Contents/Versions/{version}/bin
    @versions.reverse_each do |v|
      bin_path = "/Applications/Postgres.app/Contents/Versions/#{v}/bin"
      return @pg_bin_path = bin_path if File.exist?("#{bin_path}/pg_ctl")
    end

    # macOS MacPorts: /opt/local/lib/postgresql{version}/bin
    @versions.reverse_each do |v|
      bin_path = "/opt/local/lib/postgresql#{v}/bin"
      return @pg_bin_path = bin_path if File.exist?("#{bin_path}/pg_ctl")
    end

    # macOS homebrew: /opt/homebrew/opt/postgresql@{version}/bin
    @versions.reverse_each do |v|
      bin_path = "/opt/homebrew/opt/postgresql@#{v}/bin"
      return @pg_bin_path = bin_path if File.exist?("#{bin_path}/pg_ctl")
    end

    # Arch AUR packages: /opt/postgresql{version}/bin
    @versions.reverse_each do |v|
      bin_path = "/opt/postgresql#{v}/bin"
      return @pg_bin_path = bin_path if File.exist?("#{bin_path}/pg_ctl")
    end

    # Unversioned fallbacks — skipped when the caller pinned a version range.
    if @versions == VERSIONS
      bin_path = "/Applications/Postgres.app/Contents/Versions/latest/bin"
      return @pg_bin_path = bin_path if File.exist?("#{bin_path}/pg_ctl")

      # Fallback: check if pg_ctl is on PATH (e.g. Fedora system packages install to /usr/bin)
      pg_ctl = `which pg_ctl 2>/dev/null`.strip
      return @pg_bin_path = File.dirname(pg_ctl) if pg_ctl.present?
    end

    raise "Cannot find pg_ctl for PostgreSQL #{@versions.first}–#{@versions.last}. " \
            "Install one of those server packages (e.g. `postgresql-#{@versions.first}` on Debian/Ubuntu)."
  end

  def initdb_path
    @initdb_path ||= "#{pg_bin_path}/initdb"
  end

  def find_free_port(range)
    range.each do |port|
      lock_file = open_port_lock(port)
      next if !lock_file

      if lock_file.flock(File::LOCK_EX | File::LOCK_NB) && port_available?(port)
        @port_lock_file = lock_file
        return port
      end
      lock_file.close
    end
  end

  def pg_port
    @pg_port ||= find_free_port(11_000..11_900)
  end

  def pg_ctl_path
    @pg_ctl_path ||= "#{pg_bin_path}/pg_ctl"
  end

  def start
    init_data_directory
    start_server_on_available_port
    @started = true

    create_database

    puts "PG server is ready and DB is loaded"
  rescue StandardError
    restore_discourse_pg_port
    release_port
    raise
  end

  def stop
    @started = false
    args = [pg_ctl_path, "-D", @pg_temp_path, "stop"]
    args = ["sudo", "-u", @pg_system_user, *args] if running_as_root?
    Open3.capture3(*args)
  ensure
    restore_discourse_pg_port
    release_port
  end

  def connection_hash
    { adapter: "postgresql", database: "discourse", port: pg_port, host: "localhost" }
  end

  def with_env(&block)
    old_host = ENV["PGHOST"]
    old_user = ENV["PGUSER"]
    old_port = ENV["PGPORT"]
    old_dev_db = ENV["DISCOURSE_DEV_DB"]
    old_rails_db = ENV["RAILS_DB"]
    old_path = ENV["PATH"]

    ENV["PGHOST"] = "localhost"
    ENV["PGUSER"] = "discourse"
    ENV["PGPORT"] = pg_port.to_s
    ENV["DISCOURSE_DEV_DB"] = "discourse"
    ENV["RAILS_DB"] = "discourse"
    # Make sure subprocess `pg_dump`/`psql` match the pinned server version.
    ENV["PATH"] = "#{pg_bin_path}:#{old_path}"

    yield
  ensure
    ENV["PGHOST"] = old_host
    ENV["PGUSER"] = old_user
    ENV["PGPORT"] = old_port
    ENV["DISCOURSE_DEV_DB"] = old_dev_db
    ENV["RAILS_DB"] = old_rails_db
    ENV["PATH"] = old_path
  end

  def remove
    raise "Error: the database must be stopped before it can be removed" if @started
    FileUtils.rm_rf @pg_temp_path
  end

  def migrate
    raise "Error: the database must be started before it can be migrated." if !@started
    ActiveRecord::Base.establish_connection(connection_hash)

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
      "--username=discourse",
      error_prefix: "Failed to initialize postgres data directory",
    )
  end

  def start_server_on_available_port
    configure_database

    puts "Starting postgres on port: #{pg_port}"
    @previous_discourse_pg_port = ENV["DISCOURSE_PG_PORT"]
    ENV["DISCOURSE_PG_PORT"] = pg_port.to_s

    start_server
  end

  def open_port_lock(port)
    path = port_lock_path(port)
    open_existing_port_lock(path)
  rescue Errno::ENOENT
    create_port_lock(path)
  end

  def open_existing_port_lock(path)
    File.open(path, File::RDONLY | File::NOFOLLOW)
  rescue Errno::EACCES, Errno::ELOOP, Errno::EPERM
    nil
  end

  def create_port_lock(path)
    File.open(path, File::RDONLY | File::CREAT | File::EXCL | File::NOFOLLOW, 0o644)
  rescue Errno::EEXIST
    open_existing_port_lock(path)
  rescue Errno::EACCES, Errno::ELOOP, Errno::EPERM
    nil
  end

  def port_lock_path(port)
    File.join(Dir.tmpdir, "#{PG_TEMP_PREFIX}_#{port}.lock")
  end

  def release_port
    @port_lock_file&.close
    @port_lock_file = nil
    @pg_port = nil
  end

  def configure_database
    FileUtils.mkdir(@pg_sock_path)
    FileUtils.chown(@pg_system_user, nil, @pg_sock_path) if running_as_root?
    conf = File.read(@pg_conf)
    conf << <<~CONF

      port = #{pg_port}
      unix_socket_directories = '#{@pg_sock_path}'
      fsync = off
      synchronous_commit = off
      full_page_writes = off
      wal_level = minimal
      max_wal_senders = 0
    CONF
    File.write(@pg_conf, conf)
  end

  def start_server
    log_file = File.join(@pg_temp_path, "server.log")
    run_command!(
      pg_ctl_path,
      "-D",
      @pg_temp_path,
      "-l",
      log_file,
      "-w",
      "-t",
      STARTUP_TIMEOUT_SECONDS.to_s,
      "start",
      error_prefix: "Failed to start postgres within #{STARTUP_TIMEOUT_SECONDS}s",
    )
  end

  def create_database
    run_command!(
      "createdb",
      "-h",
      "localhost",
      "-p",
      pg_port.to_s,
      "-U",
      "discourse",
      "discourse",
      error_prefix: "Failed to create temporary postgres database",
    )
  end

  def run_command!(*args, error_prefix:)
    args = ["sudo", "-u", @pg_system_user, *args] if running_as_root?
    stdout, stderr, status = Open3.capture3(*args)
    return if status.success?

    details = stderr.to_s.strip
    details = stdout.to_s.strip if details.empty?
    details = "unknown error" if details.empty?
    raise "#{error_prefix}: #{details}"
  rescue Errno::ENOENT => e
    raise "#{error_prefix}: #{e.message}"
  end

  def running_as_root?
    Process.uid == 0
  end

  def restore_discourse_pg_port
    ENV["DISCOURSE_PG_PORT"] = @previous_discourse_pg_port
    @previous_discourse_pg_port = nil
  end
end
