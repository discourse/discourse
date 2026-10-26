# frozen_string_literal: true
if ENV["DISCOURSE_CI_RUBY_WALL_PROFILE"] == "1"
  require "fileutils"
  require "json"
  require "time"
  require "vernier"

  directory = "tmp/ruby-wall-profiles"
  FileUtils.mkdir_p(directory)
  worker = ENV.fetch("TEST_ENV_NUMBER", "unnumbered")
  prefix = "#{directory}/worker-#{worker}-pid-#{Process.pid}"
  profile_path = "#{prefix}.vernier.json.gz"
  metadata_path = "#{prefix}.metadata.json"
  clock = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
  metadata = {
    state: "starting",
    pid: Process.pid,
    parent_pid: Process.ppid,
    worker: worker,
    program: $PROGRAM_NAME,
    argv: ARGV.dup,
    ruby: RUBY_DESCRIPTION,
    vernier_version: Vernier::VERSION,
    mode: "wall",
    interval_us: 5000,
    allocation_interval: 0,
    profile_path: profile_path,
    started_at: Time.now.utc.iso8601(6),
    start_monotonic_seconds: clock.call,
    excluded_from_performance_comparisons: true,
  }

  begin
    Vernier.start_profile(mode: :wall, interval: 5000, allocation_interval: 0, out: profile_path)
    metadata[:capture_started_monotonic_seconds] = clock.call
    metadata[:state] = "capturing"
  rescue Exception => error
    metadata[:state] = "start_failed"
    metadata[:exception] = { class: error.class.name, message: error.message }
    raise
  ensure
    File.write(metadata_path, JSON.pretty_generate(metadata))
  end

  at_exit do
    metadata[:exit_status] = $!.status if $!.is_a?(SystemExit)
    metadata[:capture_finished_at] = Time.now.utc.iso8601(6)
    metadata[:capture_finished_monotonic_seconds] = clock.call
    metadata[:capture_elapsed_seconds] = metadata[:capture_finished_monotonic_seconds] -
      metadata[:capture_started_monotonic_seconds]
    metadata[:state] = "stopping_and_exporting"
    File.write(metadata_path, JSON.pretty_generate(metadata))
    stop_started_seconds = clock.call

    begin
      Vernier.stop_profile
      metadata[:state] = "complete"
      metadata[:profile_size_bytes] = File.size(profile_path)
    rescue Exception => error
      metadata[:state] = "stop_failed"
      metadata[:exception] = { class: error.class.name, message: error.message }
      raise
    ensure
      metadata[:stop_and_export_elapsed_seconds] = clock.call - stop_started_seconds
      metadata[:export_finished_at] = Time.now.utc.iso8601(6)
      File.write(metadata_path, JSON.pretty_generate(metadata))
    end
  end
end
