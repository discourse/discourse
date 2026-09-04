# frozen_string_literal: true

# Shared plumbing for the three upload benchmark scripts:
#
#   * upload_corpus.rb          - deterministic corpus generator
#   * upload_worker_scaling.rb  - drives the real Uploader pipeline at fixed
#                                 worker counts
#   * upload_creator_profile.rb - per-stage wall-clock breakdown of create_for
#
# Unlike the other benchmarks in this directory (standalone bundler/inline
# scripts), these need the Discourse Rails environment plus the migrations gems.
# They bootstrap Bundler the same way the `disco` binary does, so run them with
# a plain `ruby`, from anywhere (the Rails boot chdir's to the repo root itself):
#
#   RAILS_ENV=test UPLOAD_BENCH_I_KNOW=1 \
#     ruby migrations/tooling/scripts/benchmarks/upload_worker_scaling.rb
#
# SAFETY: the scaling and profile scripts create real Upload records and store
# real files. They refuse to run unless UPLOAD_BENCH_I_KNOW=1 is set, and they
# refuse an S3-backed store unless UPLOAD_BENCH_ALLOW_S3=1 is also set. Point
# them at a throwaway site only (RAILS_ENV=test uses the discourse_test DB and a
# local store, which is the intended setup).

require "etc"

module UploadBench
  OPT_IN_ENV = "UPLOAD_BENCH_I_KNOW"
  ALLOW_S3_ENV = "UPLOAD_BENCH_ALLOW_S3"

  REPO_ROOT = File.expand_path("../../../..", __dir__)

  class Error < StandardError
  end

  # Bundler + migrations gems, no Rails. Enough for the corpus generator, which
  # only needs the SQLite/IntermediateDB helpers and Migrations::ID.
  def self.setup!
    return if @setup_done

    ENV["BUNDLE_GEMFILE"] ||= File.join(REPO_ROOT, "Gemfile")
    require "bundler"
    Bundler.setup(:default, :migrations)

    require "migrations-core"
    require "migrations-importer"
    Migrations.enable_i18n
    Migrations.apply_global_config

    # These native gems live in the :migrations Bundler group and are otherwise
    # required lazily (when Zeitwerk first loads Database/ID). Booting Rails
    # afterwards rebuilds the load-path cache without that group, so a later lazy
    # require can't find them. Load them now, while the group is on the path.
    require "extralite"
    require "digest/xxhash"

    @setup_done = true
  end

  # Full Rails boot for the scripts that actually run UploadCreator, guarded so
  # it can never quietly hammer a production-looking site.
  def self.boot_rails_safely!
    setup!
    ensure_opt_in!
    Migrations.load_rails_environment(quiet: true)
    ensure_safe_target!
    install_force_optimize! if force_optimize?
    install_store_latency!
  end

  def self.ensure_opt_in!
    return if ENV[OPT_IN_ENV] == "1"

    raise Error, <<~MSG
      Refusing to run: these scripts create real Upload records and store files.
      Set #{OPT_IN_ENV}=1 and point RAILS_ENV at a throwaway database (e.g.
      RAILS_ENV=test) before running.
    MSG
  end

  # A production site almost always stores uploads on S3; a local store is the
  # tell-tale of a throwaway dev/test site. Refuse S3 unless explicitly allowed.
  def self.ensure_safe_target!
    return unless SiteSetting.enable_s3_uploads
    return if ENV[ALLOW_S3_ENV] == "1"

    raise Error, <<~MSG
      Refusing to run against an S3-backed store (enable_s3_uploads is on). This
      looks like a real site. Set #{ALLOW_S3_ENV}=1 only if you are certain the
      target bucket is throwaway.
    MSG
  end

  # The migration runs in production, where UploadCreator optimizes images
  # (convert/oxipng/jpegoptim/downsize). In RAILS_ENV=test those stages are
  # skipped unless the caller passes `force_optimize`. Since the whole point of
  # the harness is to measure that cooking cost, force it on by default. Set
  # UPLOAD_BENCH_FORCE_OPTIMIZE=0 to measure the bare (test-mode) path instead.
  def self.force_optimize?
    ENV.fetch("UPLOAD_BENCH_FORCE_OPTIMIZE", "1") == "1"
  end

  def self.install_force_optimize!
    return if @force_optimize_installed

    mod =
      Module.new do
        def initialize(file, filename, opts = {})
          super(file, filename, opts.merge(force_optimize: true))
        end
      end
    UploadCreator.prepend(mod)
    @force_optimize_installed = true
  end

  # --- Simulated store latency ---------------------------------------------
  #
  # On a local store, store_upload is a near-instant file copy, so a worker
  # never parks waiting on I/O. Production uploads to S3, where each PUT blocks
  # the worker on the network for tens to hundreds of milliseconds. That parking
  # is what makes extra pipeline workers pay off in production but not on a local
  # box, so the scaling curves look different.
  #
  # To model that here we wrap the store's store_upload in a sleep of the
  # configured latency. sleep RELEASES THE GVL, so while one worker sleeps the
  # others keep running - exactly the worker-parking behaviour of a real S3 PUT.
  # This is deliberately a crude model: it captures the parking effect ONLY. It
  # does NOT reproduce aws-sdk's own CPU cost (signing, TLS, response parsing) or
  # its HTTP connection-pool ceiling, so treat the latency runs as an upper bound
  # on how well more workers can help, not a prediction of S3 numbers.
  #
  # store_latency_ms / store_latency_jitter are read fresh on every call, so a
  # driver (the scaling matrix) can sweep latency values without reinstalling.
  class << self
    attr_writer :store_latency_ms, :store_latency_jitter
  end

  def self.store_latency_ms
    @store_latency_ms ||= env_int("UPLOAD_BENCH_STORE_LATENCY_MS", 0)
  end

  # Fraction of the base latency to spread the sleep over, uniform in
  # +/- jitter (0.3 => +/-30%). Off (0) by default so a run is repeatable.
  def self.store_latency_jitter
    @store_latency_jitter ||= env_float("UPLOAD_BENCH_STORE_LATENCY_JITTER", 0.0)
  end

  def self.install_store_latency!
    return if @store_latency_installed

    Discourse.store.class.prepend(
      Module.new do
        def store_upload(*, &)
          UploadBench.store_sleep!
          super
        end
      end,
    )
    @store_latency_installed = true
  end

  def self.store_sleep!
    base_ms = store_latency_ms.to_f
    return if base_ms <= 0

    jitter = store_latency_jitter.to_f
    factor = jitter > 0 ? 1.0 + jitter * (rand * 2 - 1) : 1.0
    seconds = base_ms * factor / 1000.0
    sleep(seconds) if seconds > 0
  end

  # --- ImageMagick thread limit --------------------------------------------
  #
  # ImageMagick does its own OpenMP threading inside each convert/identify
  # subprocess, honouring the MAGICK_THREAD_LIMIT env var (verified via
  # `magick -list resource`: default Thread: <cores>, with the var set Thread: 1).
  # The subprocesses inherit our environment, so setting it here caps them. Pass
  # nil to fully remove the var (an empty string is NOT "unset" - ImageMagick
  # reads empty as 1).
  def self.with_magick_thread_limit(limit)
    key = "MAGICK_THREAD_LIMIT"
    had_key = ENV.key?(key)
    previous = ENV[key]

    limit.nil? ? ENV.delete(key) : ENV[key] = limit.to_s
    yield
  ensure
    had_key ? ENV[key] = previous : ENV.delete(key)
  end

  # --- CPU sampling via /proc/stat -----------------------------------------
  #
  # Subprocess time (convert, oxipng, ...) is invisible to Ruby's own clocks, so
  # we read the kernel's aggregate CPU counters instead. A snapshot is the busy
  # and total jiffies summed across all cores; the delta between two snapshots
  # over a run tells us how many cores were actually kept busy.

  CpuSnapshot = Struct.new(:busy, :total)

  def self.cpu_snapshot
    line = File.foreach("/proc/stat").find { |l| l.start_with?("cpu ") }
    return nil unless line

    values = line.split[1..].map(&:to_i)
    # user nice system idle iowait irq softirq steal guest guest_nice
    idle = values[3] + values[4] # idle + iowait
    total = values.sum
    CpuSnapshot.new(total - idle, total)
  end

  # @return [Hash] :cpu_percent (0-100 of the whole machine) and :cores_busy
  #   (equivalent number of fully-busy cores) between two snapshots.
  def self.cpu_usage(before, after)
    return { cpu_percent: nil, cores_busy: nil } unless before && after

    total_delta = after.total - before.total
    return { cpu_percent: nil, cores_busy: nil } if total_delta <= 0

    busy_fraction = (after.busy - before.busy).to_f / total_delta
    { cpu_percent: (busy_fraction * 100).round(1), cores_busy: (busy_fraction * nproc).round(2) }
  end

  def self.nproc
    @nproc ||= Etc.nprocessors
  end

  def self.monotonic
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def self.env_int(name, default)
    value = ENV[name]
    value && !value.empty? ? Integer(value) : default
  end

  def self.env_float(name, default)
    value = ENV[name]
    value && !value.empty? ? Float(value) : default
  end

  def self.env_ints(name, default)
    value = ENV[name]
    return default if value.nil? || value.empty?
    value.split(",").map { |v| Integer(v.strip) }
  end

  # A reporter that swallows all output. The pipeline needs a reporter, but the
  # benchmark does its own timing and we don't want progress noise skewing the
  # measurement or the console.
  def self.quiet_reporter
    Class
      .new(Migrations::Reporting::Reporter) do
        def report_start(_id, _title)
        end

        def report_notice(_id, _message)
        end

        def report_progress_begin(_id, _max_progress)
        end

        def report_concurrency(_id, _count)
        end

        def report_progress(_id, _current, _skip, _warning, _error)
        end

        def report_finish(_id, _outcome)
        end
      end
      .new
  end
end
