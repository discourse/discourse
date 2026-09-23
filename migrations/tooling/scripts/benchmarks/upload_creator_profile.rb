# frozen_string_literal: true

# Per-stage wall-clock breakdown of UploadCreator#create_for, run over a handful
# of representative files (one per corpus image tier, plus a binary attachment).
#
# Most of UploadCreator's cost is in ImageMagick / oxipng / jpegoptim
# subprocesses, which Ruby's sampling profilers can't see, so wall-clock per
# stage is the measurement that matters. stackprof (in-GVL) and memory_profiler
# (allocations) passes are available behind flags for the Ruby-side cost.
#
# The stages map onto the ranked hypotheses from the design review:
#   sha1 (generate_digest)   - computed up to 3x per upload
#   distributed_mutex        - 2x Redis round-trip per upload (measured separately)
#   target_image_quality     - `identify -format %Q` subprocess per image
#   dominant_color           - `convert ... histogram` subprocess per image
#   optimize                 - image_optim / oxipng level 3, cost grows with PNG size
#   task_tempfile_copy       - the extra full-file copy the Uploader task makes
#
# On top of the wall-clock stages, it also profiles the SQL and Redis round-trips
# create_for fires, because stackprof puts ~35% of the in-GVL time in
# `PG::Connection#exec`. Per file type it reports every normalized query (name,
# stripped SQL, call count, total ms), the Redis round-trip count, and a
# raw-libpq-vs-ActiveRecord microbenchmark that splits the SQL wall time into
# server work vs Ruby/AR overhead. This is what tells us which queries are
# skippable or batchable in a migration context.
#
# Run against a THROWAWAY site only (see upload_bench_support.rb):
#
#   RAILS_ENV=test UPLOAD_BENCH_I_KNOW=1 \
#     ruby migrations/tooling/scripts/benchmarks/upload_creator_profile.rb
#
# Flags (env vars):
#   PROFILE_STACKPROF=1  wrap the run in StackProf (wall mode), dump top frames
#   PROFILE_MEMORY=1     run one create_for through memory_profiler
#   PROFILE_SQL=0        skip the SQL / Redis query profiling (on by default)
#   PROFILE_IMAGES       number of corpus images (default 18: ~10 jpg, ~6 png, 2 gif)
#   PROFILE_ATTACHMENTS  number of corpus attachments (default 12)
#   PROFILE_SEED         corpus seed (default 9000)

require_relative "upload_bench_support"
require_relative "upload_corpus"

require "fileutils"
require "json"
require "tmpdir"

UploadBench.boot_rails_safely!
RubyVM::YJIT.enable if defined?(RubyVM::YJIT) && RubyVM::YJIT.respond_to?(:enable)

module UploadBench
  # Accumulates wall-clock time and call counts per named stage. Single-threaded:
  # the profiler drives create_for one file at a time.
  module Profile
    class << self
      def reset!
        @time = Hash.new(0.0)
        @count = Hash.new(0)
      end

      def measure(stage)
        started = UploadBench.monotonic
        yield
      ensure
        @time[stage] += UploadBench.monotonic - started
        @count[stage] += 1
      end

      attr_reader :time, :count
    end
  end

  # Collects every `sql.active_record` event fired while `active` is set, keyed by
  # (query name, normalized SQL). Single-threaded: the profiler drives one file at
  # a time, and only create_for runs inside the active window, so warmup, cleanup
  # and the microbenchmark are excluded. Literals, bind placeholders ($1) and the
  # marginalia comment Discourse appends are stripped so the same statement shape
  # collapses into one row regardless of the values it ran with.
  module SqlCollector
    class << self
      attr_accessor :active

      def reset!
        @queries =
          Hash.new { |h, k| h[k] = { name: k.first, sql: k.last, count: 0, total_ms: 0.0 } }
      end

      def install!
        require "active_support/notifications"
        @subscriber ||=
          ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
            record(ActiveSupport::Notifications::Event.new(*args)) if @active
          end
      end

      def record(event)
        payload = event.payload
        return if payload[:cached]

        name = payload[:name] || "(tx/other)"
        row = @queries[[name, normalize(payload[:sql].to_s)]]
        row[:count] += 1
        row[:total_ms] += event.duration
      end

      # Ranked rows, biggest total_ms first.
      def rows
        @queries.values.sort_by { |r| -r[:total_ms] }
      end

      def total_count
        @queries.values.sum { |r| r[:count] }
      end

      def total_ms
        @queries.values.sum { |r| r[:total_ms] }
      end

      def normalize(sql)
        s = sql.dup
        s.gsub!(%r{/\*.*?\*/}m, " ") # strip marginalia (application/thread_id comment)
        s.gsub!(/\$\d+/, "?") # pg bind placeholders
        s.gsub!(/'(?:[^']|'')*'/, "?") # string literals
        s.gsub!(/\b\d+\b/, "?") # numeric literals
        s.gsub!(/\?(?:\s*,\s*\?)+/, "?") # collapse IN (?, ?, ...) lists
        s.gsub!(/\s+/, " ")
        s.strip
      end
    end
  end

  # Counts Redis round-trips fired on the profiling thread while `active` is set,
  # via a redis-client middleware. Background threads (MessageBus, etc.) share the
  # client but run on other threads, so filtering by thread keeps their noise out.
  module RedisCollector
    class << self
      attr_accessor :active, :thread

      def reset!
        @round_trips = 0
        @commands = 0
      end

      attr_reader :round_trips, :commands

      def available?
        @available
      end

      def install!
        require "redis-client"
        RedisClient.register(Middleware)
        @available = true
      rescue LoadError, StandardError
        @available = false
      end

      def note(commands)
        return unless @active && Thread.current == @thread

        @round_trips += 1
        @commands += commands
      end
    end

    module Middleware
      def call(command, config)
        RedisCollector.note(1)
        super
      end

      def call_pipelined(commands, config)
        RedisCollector.note(commands.size)
        super
      end
    end
  end

  module Instrument
    UPLOAD_CREATOR_STAGES = %i[
      extract_image_info!
      convert_to_jpeg!
      fix_orientation!
      crop!
      optimize!
      downsize!
      clean_svg!
      convert_heif!
      convert_favicon_to_png!
    ].freeze

    def self.install!
      creator_mod =
        Module.new do
          UPLOAD_CREATOR_STAGES.each do |name|
            define_method(name) { |*a, **k, &b| Profile.measure(name) { super(*a, **k, &b) } }
          end
        end
      ::UploadCreator.prepend(creator_mod)

      ::Upload.singleton_class.prepend(
        Module.new do
          def generate_digest(path)
            Profile.measure(:sha1_generate_digest) { super }
          end
        end,
      )

      ::Upload.prepend(
        Module.new do
          def calculate_dominant_color!(local_path = nil)
            Profile.measure(:dominant_color) { super }
          end

          def target_image_quality(local_path, test_quality)
            Profile.measure(:target_image_quality) { super }
          end
        end,
      )
    end
  end

  class CreatorProfile
    include Migrations

    def initialize
      @seed = UploadBench.env_int("PROFILE_SEED", 9000)
      @images = UploadBench.env_int("PROFILE_IMAGES", 18)
      @attachments = UploadBench.env_int("PROFILE_ATTACHMENTS", 12)
      @profile_sql = ENV.fetch("PROFILE_SQL", "1") == "1"
      @work_dir = Dir.mktmpdir("upload-profile")
    end

    def run
      @baseline_id = ::Upload.maximum(:id) || 0
      Importer::Uploads::SiteSettings.configure!(site_settings_options)
      Instrument.install!
      install_query_collectors

      corpus =
        Corpus.generate(
          dir: File.join(@work_dir, "corpus"),
          seed: @seed,
          images: @images,
          attachments: @attachments,
          max_attachment_bytes: 8 * 1024 * 1024,
        )

      files = Dir.children(corpus.files_dir).sort.map { |f| File.join(corpus.files_dir, f) }

      puts "UploadCreator per-stage wall-clock profile"
      puts "  ruby:           #{RUBY_DESCRIPTION}"
      puts "  rails env:      #{Rails.env}"
      puts "  force_optimize: #{UploadBench.force_optimize?}"
      puts "  files:          #{files.size}"
      puts "  sql profiling:  #{@profile_sql}"
      puts

      # One throwaway create_for primes AR's schema-column cache and query plans,
      # so the first profiled category doesn't get charged for SCHEMA introspection
      # queries that only ever run once per process.
      warmup(files.first) if @profile_sql

      measure_distributed_mutex

      grouped = files.group_by { |path| category(path) }
      maybe_stackprof { grouped.each { |category, paths| profile_category(category, paths) } }
      measure_client_server_split if @profile_sql
      maybe_memory_profile(files.find { |f| category(f) == "png" } || files.first)
    ensure
      cleanup
      FileUtils.rm_rf(@work_dir)
    end

    private

    def category(path)
      ext = File.extname(path).downcase.delete(".")
      %w[jpg jpeg png gif].include?(ext) ? ext.sub("jpeg", "jpg") : "attachment"
    end

    def profile_category(category, paths)
      Profile.reset!
      SqlCollector.reset! if @profile_sql
      RedisCollector.reset! if @profile_sql
      collectors_active(true)
      total = 0.0
      paths.each { |path| total += process_one(path) }
      collectors_active(false)

      puts "== #{category} (#{paths.size} files, #{(total * 1000).round(1)} ms total create_for) =="
      rows =
        Profile
          .time
          .map { |stage, secs| [stage, Profile.count[stage], secs] }
          .sort_by { |_, _, secs| -secs }

      puts format("  %-24s %6s %10s %10s %8s", *%w[stage calls total_ms ms/file %create])
      rows.each do |stage, calls, secs|
        share = total > 0 ? (secs / total * 100) : 0
        puts format(
               "  %-24s %6d %10.2f %10.2f %7.1f%%",
               stage,
               calls,
               secs * 1000,
               secs * 1000 / paths.size,
               share,
             )
      end
      puts

      report_sql(category, paths.size, total) if @profile_sql
    end

    def collectors_active(state)
      return unless @profile_sql

      SqlCollector.active = state
      RedisCollector.active = state
    end

    def report_sql(category, file_count, total_secs)
      sql_ms = SqlCollector.total_ms
      share = total_secs > 0 ? sql_ms / (total_secs * 1000) * 100 : 0
      puts "  -- SQL for #{category}: #{SqlCollector.total_count} queries over #{file_count} " \
             "create_for (#{(SqlCollector.total_count.to_f / file_count).round(1)}/file), " \
             "#{sql_ms.round(1)} ms total (#{share.round(1)}% of create_for wall time)"
      if RedisCollector.available?
        puts "  -- Redis for #{category}: #{RedisCollector.round_trips} round-trips " \
               "(#{(RedisCollector.round_trips.to_f / file_count).round(1)}/file), " \
               "#{RedisCollector.commands} commands (profiling thread only)"
      end

      puts format("  %-22s %5s %7s %8s %8s  %s", *%w[name calls /file total_ms ms/call sql])
      SqlCollector.rows.each do |r|
        puts format(
               "  %-22s %5d %7.1f %8.2f %8.3f  %s",
               truncate(r[:name], 22),
               r[:count],
               r[:count].to_f / file_count,
               r[:total_ms],
               r[:total_ms] / r[:count],
               truncate(r[:sql], 90),
             )
      end
      puts
    end

    def truncate(str, len)
      str.length > len ? "#{str[0, len - 1]}…" : str
    end

    # Returns create_for wall-clock seconds for one file, including the extra
    # tempfile copy the real Uploader task makes before handing the file over.
    def process_one(path)
      started = UploadBench.monotonic
      copy_to_tempfile(path) do |file|
        UploadCreator.new(file, File.basename(path), type: nil).create_for(
          Discourse::SYSTEM_USER_ID,
        )
      end
      UploadBench.monotonic - started
    end

    def copy_to_tempfile(source_path)
      Profile.measure(:task_tempfile_copy) do
        @tempfile = Tempfile.open(["profile-upload", File.extname(source_path)], binmode: true)
        File.open(source_path, "rb") { |src| IO.copy_stream(src, @tempfile) }
        @tempfile.rewind
      end
      yield(@tempfile)
    ensure
      @tempfile&.close!
    end

    def install_query_collectors
      return unless @profile_sql

      SqlCollector.install!
      RedisCollector.thread = Thread.current
      RedisCollector.install!
    end

    def warmup(path)
      Profile.reset! # copy_to_tempfile records into Profile; give it somewhere to go
      copy_to_tempfile(path) do |file|
        UploadCreator.new(file, File.basename(path), type: nil).create_for(
          Discourse::SYSTEM_USER_ID,
        )
      end
      # Drop the warmup upload again: otherwise its sha1 is on file and the same
      # corpus file dedupes when its category runs, skewing that type's query count.
      ::Upload.where("id > ?", @baseline_id).delete_all
    end

    # How much of the SQL wall time is Postgres actually working vs Ruby/AR/driver
    # overhead around the call? pg_stat_statements isn't loaded here (not in
    # shared_preload_libraries), so instead run the SAME statement two ways over
    # the same unix socket: raw libpq (`PG::Connection#exec`, ~server + protocol
    # round-trip) and through ActiveRecord (`connection.select_all`, which adds the
    # notification instrumentation, query-cache check and result type-casting). The
    # gap between them is the Ruby/AR overhead per query. An EXPLAIN ANALYZE of the
    # indexed lookup shows the server-side execution time on its own.
    def measure_client_server_split
      ar = ::ActiveRecord::Base.connection
      raw = ar.raw_connection
      sha1 = ::Upload.where("id > ?", @baseline_id).limit(1).pick(:sha1) || ("0" * 40)

      cases = {
        "SELECT 1" => "SELECT 1",
        "uploads by sha1 (indexed)" =>
          "SELECT * FROM uploads WHERE sha1 = #{ar.quote(sha1)} LIMIT 1",
      }

      puts "== SQL client/server split (raw libpq vs ActiveRecord, same unix socket) =="
      puts "  (raw = server exec + protocol round-trip; AR - raw = Ruby/AR overhead per query)"
      puts format("  %-28s %10s %10s %12s %8s", *%w[query raw_us ar_us overhead_us ar_over%])
      iterations = 3000
      ar.uncached do
        cases.each do |label, sql|
          20.times { raw.exec(sql) } # warm plan/JIT
          raw_s = time_loop(iterations) { raw.exec(sql) }
          20.times { ar.select_all(sql) }
          ar_s = time_loop(iterations) { ar.select_all(sql) }
          raw_us = raw_s / iterations * 1e6
          ar_us = ar_s / iterations * 1e6
          over = ar_us - raw_us
          pct = ar_us > 0 ? over / ar_us * 100 : 0
          puts format("  %-28s %10.1f %10.1f %12.1f %7.1f%%", label, raw_us, ar_us, over, pct)
        end
      end

      explain =
        ar
          .select_all(
            "EXPLAIN (ANALYZE, TIMING, FORMAT JSON) " \
              "SELECT * FROM uploads WHERE sha1 = #{ar.quote(sha1)} LIMIT 1",
          )
          .rows
          .first
          &.first
      explain = JSON.parse(explain) if explain.is_a?(String)
      exec_ms = explain&.first&.dig("Execution Time")
      if exec_ms
        puts format("  server exec time for the sha1 lookup (EXPLAIN ANALYZE): %.3f ms", exec_ms)
      end
      puts
    rescue StandardError => e
      puts "  client/server split skipped: #{e.class}: #{e.message.lines.first&.strip}"
      puts
    end

    def time_loop(iterations)
      started = UploadBench.monotonic
      iterations.times { yield }
      UploadBench.monotonic - started
    end

    # DistributedMutex wraps the whole image-processing block, so its overhead
    # can't be teased out by wrapping the call. Measure the bare lock/unlock cost
    # (2 Redis round-trips) directly instead.
    def measure_distributed_mutex
      iterations = 200
      started = UploadBench.monotonic
      iterations.times { |i| DistributedMutex.synchronize("upload-bench-#{i}") {} }
      per_call_ms = (UploadBench.monotonic - started) / iterations * 1000
      puts "DistributedMutex: #{per_call_ms.round(3)} ms/upload (empty lock/unlock, #{iterations}x)"
      puts
    end

    def maybe_stackprof
      return yield unless ENV["PROFILE_STACKPROF"] == "1"

      require "stackprof"
      out = File.join(@work_dir, "stackprof.dump")
      StackProf.run(mode: :wall, interval: 1000, raw: true, out:) { yield }
      report_stackprof(out)
    end

    def report_stackprof(out)
      # Loading a stackprof dump we just wrote ourselves; not untrusted input.
      report = StackProf::Report.new(Marshal.load(File.binread(out))) # rubocop:disable Security/MarshalLoad
      puts "== stackprof (wall, in-GVL only; subprocess time is invisible) =="
      report.print_text(false, 15)
      puts
    end

    def maybe_memory_profile(path)
      return unless ENV["PROFILE_MEMORY"] == "1"

      require "memory_profiler"
      puts "== memory_profiler: one create_for (#{File.basename(path)}) =="
      report = MemoryProfiler.report { process_one(path) }
      puts "  total allocated: #{report.total_allocated} objects, " \
             "#{report.total_allocated_memsize} bytes"
      puts "  total retained:  #{report.total_retained} objects, " \
             "#{report.total_retained_memsize} bytes"
      puts "  top allocating locations:"
      report
        .allocated_memory_by_location
        .first(10)
        .each { |row| puts format("    %10d B  %s", row[:count], row[:data]) }
      puts
    end

    def site_settings_options
      {
        authorized_extensions: "*",
        max_attachment_size_kb: 100 * 1024,
        max_image_size_kb: 4096,
        enable_s3_uploads: false,
        multisite: false,
      }
    end

    # Delete only the uploads this run created.
    def cleanup
      ::Upload.where("id > ?", @baseline_id || 0).delete_all
    end
  end
end

UploadBench::CreatorProfile.new.run
