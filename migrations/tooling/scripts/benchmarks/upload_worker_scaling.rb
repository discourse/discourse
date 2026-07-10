# frozen_string_literal: true

# Drives the REAL upload pipeline (Migrations::Importer::Uploads::Tasks::Uploader
# on Pipeline) against a synthetic corpus at a series of FIXED worker counts, so
# we can see how throughput and CPU utilisation scale with concurrency. A later
# PR replaces the static worker count with an adaptive controller; its dead-band
# thresholds and plateau guard need these curves, not guesses.
#
# For each (workload x worker count) it reports items/s and CPU busy (measured
# from /proc/stat deltas, since the heavy work is in convert/oxipng subprocesses
# that Ruby's own profilers can't see).
#
# Run it against a THROWAWAY site only (see upload_bench_support.rb for the
# guard). The intended setup is RAILS_ENV=test with the local store:
#
#   RAILS_ENV=test UPLOAD_BENCH_I_KNOW=1 \
#     ruby migrations/tooling/scripts/benchmarks/upload_worker_scaling.rb
#
# Two extra dimensions let the matrix probe what changes off a local dev box:
#
#   * Simulated store latency wraps the local store's store_upload in a sleep, so
#     a worker parks on each "PUT" the way it would against S3. sleep releases the
#     GVL, so it models the worker-parking effect (why more workers help in
#     production) but NOT aws-sdk CPU or its connection-pool ceiling. See
#     upload_bench_support.rb for the full caveat.
#   * MAGICK_THREAD_LIMIT caps the OpenMP threads inside each ImageMagick
#     subprocess, so we can compare internally-threaded convert (default, a few
#     workers saturate the cores) against single-threaded convert with many
#     workers.
#
# Configuration (env vars):
#   SCALING_WORKERS         comma list of worker counts (default 1,2,4,8,16,32,64)
#   SCALING_WORKLOADS       comma list of images,attachments,mixed (default all)
#   SCALING_IMAGES          images per corpus (default 120)
#   SCALING_ATTACHMENTS     attachments per corpus (default 40)
#   SCALING_MAX_ATTACH_MB   largest attachment (default 10)
#   SCALING_SEED            base corpus seed (default 7000)
#   SCALING_STORE_LATENCIES comma list of store latencies in ms to sweep
#                           (default from UPLOAD_BENCH_STORE_LATENCY_MS, else 0)
#   SCALING_STORE_LATENCY_JITTER  +/- fraction applied to every latency cell
#                           (default from UPLOAD_BENCH_STORE_LATENCY_JITTER, else 0)
#   SCALING_MAGICK_THREAD_LIMITS  comma list of MAGICK_THREAD_LIMIT values to
#                           sweep; "unset" means don't set it (default unset)
#   SCALING_BATCH_SIZE      rows per work batch (default = Pipeline default, 32)
#   UPLOAD_BENCH_FORCE_OPTIMIZE  1 (default) runs the real image cooking path
#                                even under RAILS_ENV=test; 0 measures the bare path
#
# The full matrix is workload x store-latency x magick-thread-limit x worker-count;
# one table is printed per (workload, latency, magick-limit) block, worker counts
# down the rows.
#
# BATCH SIZE MATTERS FOR SCALING. Workers pop whole batches, not single rows, so
# the producer only makes ceil(items / batch_size) batches and never more than
# that many workers can run at once. With the default batch_size of 32 a 60-item
# corpus is just 2 batches, so it can't exercise more than ~2 workers no matter
# how many you ask for — the curve looks like an early "plateau" that is really
# starvation. A real import has millions of rows (thousands of batches), so to
# reproduce its scaling on a small corpus you must keep items >= batch_size x
# max_workers; lower SCALING_BATCH_SIZE when the corpus is small.
#
# Comparability: one corpus is generated per workload (identical bytes across all
# cells). Each run uses a fresh output SQLite DB, and the Upload rows it created
# in Postgres are deleted afterwards, so UploadCreator's sha1 dedup never
# short-circuits the next run — every run does the full work on the same corpus.

require_relative "upload_bench_support"
require_relative "upload_corpus"

require "fileutils"
require "securerandom"
require "tmpdir"

UploadBench.boot_rails_safely!
RubyVM::YJIT.enable if defined?(RubyVM::YJIT) && RubyVM::YJIT.respond_to?(:enable)

module UploadBench
  class WorkerScaling
    include Migrations

    RunResult =
      Struct.new(
        :workers,
        :items,
        :ok,
        :seconds,
        :items_per_sec,
        :cpu_percent,
        :cores_busy,
        :latency_ms,
        :magick_limit,
      )

    WORKLOADS = {
      "images" => {
        images: :count,
        attachments: 0,
      },
      "attachments" => {
        images: 0,
        attachments: :count,
      },
      "mixed" => {
        images: :count,
        attachments: :count,
      },
    }.freeze

    def initialize
      @worker_counts = UploadBench.env_ints("SCALING_WORKERS", [1, 2, 4, 8, 16, 32, 64])
      @workloads = (ENV["SCALING_WORKLOADS"] || "images,attachments,mixed").split(",").map(&:strip)
      @images = UploadBench.env_int("SCALING_IMAGES", 120)
      @attachments = UploadBench.env_int("SCALING_ATTACHMENTS", 40)
      @max_attach_mb = UploadBench.env_int("SCALING_MAX_ATTACH_MB", 10)
      @seed = UploadBench.env_int("SCALING_SEED", 7000)
      @latencies = UploadBench.env_ints("SCALING_STORE_LATENCIES", [UploadBench.store_latency_ms])
      @latency_jitter =
        UploadBench.env_float("SCALING_STORE_LATENCY_JITTER", UploadBench.store_latency_jitter)
      @magick_limits = parse_magick_limits
      @batch_size =
        UploadBench.env_int("SCALING_BATCH_SIZE", Importer::Uploads::Pipeline::DEFAULT_BATCH_SIZE)
      @work_dir = Dir.mktmpdir("upload-scaling")
    end

    # "unset" (or empty) keeps MAGICK_THREAD_LIMIT off; anything else is an integer
    # thread cap. Default: a single "unset" cell, i.e. the previous behaviour.
    def parse_magick_limits
      raw = ENV["SCALING_MAGICK_THREAD_LIMITS"]
      return [nil] if raw.nil? || raw.empty?

      raw
        .split(",")
        .map(&:strip)
        .map { |v| v.empty? || v.casecmp?("unset") || v.casecmp?("none") ? nil : Integer(v) }
    end

    def run
      bump_db_pool!
      configure_site_settings!

      puts "Upload worker scaling benchmark"
      puts "  ruby:            #{RUBY_DESCRIPTION}"
      puts "  cores:           #{UploadBench.nproc}"
      puts "  rails env:       #{Rails.env}"
      puts "  store:           #{Discourse.store.class} (external=#{Discourse.store.external?})"
      puts "  force_optimize:  #{UploadBench.force_optimize?}"
      puts "  worker counts:   #{@worker_counts.join(", ")}"
      puts "  batch size:      #{@batch_size}"
      puts "  store latencies: #{@latencies.map { |l| "#{l}ms" }.join(", ")}" \
             "#{@latency_jitter > 0 ? " (+/-#{(@latency_jitter * 100).round}%)" : ""}"
      puts "  magick limits:   #{@magick_limits.map { |l| l.nil? ? "unset" : l }.join(", ")}"
      puts

      @workloads.each { |workload| run_workload(workload) }
    ensure
      FileUtils.rm_rf(@work_dir)
    end

    private

    def run_workload(workload)
      spec = WORKLOADS.fetch(workload) { abort "Unknown workload: #{workload}" }
      images = spec[:images] == :count ? @images : 0
      attachments = spec[:attachments] == :count ? @attachments : 0

      puts "== workload: #{workload} (#{images} images, #{attachments} attachments) =="
      corpus =
        Corpus.generate(
          dir: File.join(@work_dir, "corpus-#{workload}"),
          seed: @seed,
          images:,
          attachments:,
          max_attachment_bytes: @max_attach_mb * 1024 * 1024,
        )

      # Same corpus reused across every latency x magick-limit x worker cell.
      @latencies.each do |latency_ms|
        @magick_limits.each do |magick_limit|
          results =
            @worker_counts.map { |workers| measure_run(corpus, workers, latency_ms, magick_limit) }
          print_table(latency_ms, magick_limit, results)
        end
      end
      puts
    ensure
      FileUtils.rm_rf(File.join(@work_dir, "corpus-#{workload}"))
    end

    def measure_run(corpus, workers, latency_ms, magick_limit)
      output_db_path = File.join(@work_dir, "out-#{workers}-#{SecureRandom.hex(4)}.sqlite3")
      settings = build_settings(corpus, output_db_path)

      Database.migrate(output_db_path, migrations_path: Database::UPLOADS_DB_SCHEMA_PATH)
      databases = {
        uploads_db: Database.connect(output_db_path),
        intermediate_db: Database.connect(corpus.db_path),
      }

      baseline_id = ::Upload.maximum(:id) || 0
      task = Importer::Uploads::Tasks::Uploader.new(databases, settings)

      UploadBench.store_latency_ms = latency_ms
      UploadBench.store_latency_jitter = @latency_jitter

      cpu_before = nil
      started = nil
      seconds = nil
      UploadBench.with_magick_thread_limit(magick_limit) do
        cpu_before = UploadBench.cpu_snapshot
        started = UploadBench.monotonic
        Importer::Uploads::Pipeline.new(
          task:,
          reporter: UploadBench.quiet_reporter,
          worker_count: workers,
          batch_size: @batch_size,
          install_trap: false,
        ).run
        seconds = UploadBench.monotonic - started
      end
      cpu = UploadBench.cpu_usage(cpu_before, UploadBench.cpu_snapshot)

      items = corpus.image_count + corpus.attachment_count
      ok =
        databases[:uploads_db].query_value("SELECT COUNT(*) FROM uploads WHERE upload IS NOT NULL")
      RunResult.new(
        workers,
        items,
        ok,
        seconds,
        (items / seconds).round(2),
        cpu[:cpu_percent],
        cpu[:cores_busy],
        latency_ms,
        magick_limit,
      )
    ensure
      databases&.each_value(&:close)
      Database.delete_database(output_db_path)
      ::Upload.where("id > ?", baseline_id).delete_all if baseline_id
    end

    def build_settings(corpus, output_db_path)
      {
        source_db_path: corpus.db_path,
        output_db_path:,
        root_paths: [corpus.files_dir],
        path_replacements: [],
        download_cache_path: File.join(@work_dir, "downloads"),
        delete_surplus_uploads: false,
        delete_missing_uploads: false,
        fix_missing: false,
        create_optimized_images: false,
        site_settings: site_settings_options,
      }
    end

    def site_settings_options
      {
        authorized_extensions: "*",
        max_attachment_size_kb: (@max_attach_mb + 10) * 1024,
        max_image_size_kb: 4096, # small enough that multi-MB images hit downsize!
        enable_s3_uploads: false,
        multisite: false,
      }
    end

    def configure_site_settings!
      FileUtils.mkdir_p(File.join(@work_dir, "downloads"))
      Importer::Uploads::SiteSettings.configure!(site_settings_options)
    end

    # Each worker thread borrows an ActiveRecord connection per item, so the pool
    # must hold at least one slot per worker plus the writer, or workers block on
    # the pool instead of on real work. Bump it (capped at Postgres max_connections).
    def bump_db_pool!
      max_workers = @worker_counts.max
      wanted = max_workers + 8
      max_connections = ::DB.query_single("SHOW max_connections").first.to_i
      target = [wanted, max_connections - 5].min

      return if ActiveRecord::Base.connection_pool.size >= target

      config = ActiveRecord::Base.connection_db_config.configuration_hash.dup
      config[:pool] = target
      ActiveRecord::Base.establish_connection(config)
      puts "DB pool size set to #{ActiveRecord::Base.connection_pool.size} " \
             "(max_connections=#{max_connections})"
    end

    def print_table(latency_ms, magick_limit, results)
      puts "  -- store latency #{latency_ms}ms, MAGICK_THREAD_LIMIT " \
             "#{magick_limit.nil? ? "unset" : magick_limit} --"
      puts format(
             "  %-8s %6s %6s %9s %10s %8s %8s %7s %7s",
             *%w[workers items ok secs items/s cpu% cores lat_ms magick],
           )
      results.each do |r|
        puts format(
               "  %-8d %6d %6d %9.2f %10.2f %8s %8s %7d %7s",
               r.workers,
               r.items,
               r.ok,
               r.seconds,
               r.items_per_sec,
               r.cpu_percent || "n/a",
               r.cores_busy || "n/a",
               r.latency_ms,
               r.magick_limit.nil? ? "unset" : r.magick_limit,
             )
      end
    end
  end
end

UploadBench::WorkerScaling.new.run
