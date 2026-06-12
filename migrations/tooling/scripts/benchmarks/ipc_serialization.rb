#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"
  gem "benchmark"
  gem "benchmark-ips"
  gem "json"
  gem "msgpack"
  gem "oj"
  gem "pg"
end

require "benchmark/ips"
require "benchmark"
require "date"
require "ipaddr"
require "json"
require "msgpack"
require "time"

# Compares serializers for the worker IPC pipeline in
# `Migrations::Conversion::Worker`:
#
#   A: Oj in `:object` mode (today's implementation) over payloads as they
#      exist today -- with Time/Date/IPAddr objects and symbol-keyed hashes
#   B: Oj in `:compat` mode over primitive-only payloads (temporal values as
#      PG text strings)
#   C: the stdlib `json` gem over primitive-only payloads, newline-delimited
#   D: Marshal over today's payloads (native Symbol/Time/Date/IPAddr/Struct
#      support, so no wire-format change would be needed)
#   E: msgpack over primitive-only payloads (binary, streaming-native)
#   F: Oj in `:strict` mode over primitive-only payloads (like B, but raises
#      on non-primitive values -- the contract-enforcing option)
#
# Two measurements per arm: in-process serialize+deserialize (benchmark-ips)
# and end-to-end throughput through the real fork + IO.pipe machinery
# replicated from `Worker` (items/sec wall clock).
#
# The pipeline measurement deliberately uses a no-op job that returns a
# prebuilt result payload, so it isolates codec + pipe costs from
# `process_item` costs. It runs once per in-flight window size (WINDOWS env,
# default "1,16"): window 1 is `Worker`'s current one-item-in-flight
# handshake, larger windows measure what that lockstep costs. At windows > 1
# multiple unconsumed documents can sit in a pipe, so those runs double as a
# soak test for each codec's open-pipe stream parsing.

ITEM_COUNT = Integer(ENV.fetch("ITEMS", "100000"))
UNIQUE_ITEM_COUNT = [ITEM_COUNT, 10_000].min
PIPELINE_RUNS_PER_ARM = Integer(ENV.fetch("RUNS", "3"))
PIPELINE_WINDOWS = ENV.fetch("WINDOWS", "1,16").split(",").map { |size| Integer(size) }

# MICRO=0 or PIPELINE=0 skips that section
RUN_MICRO = ENV.fetch("MICRO", "1") == "1"
RUN_PIPELINE = ENV.fetch("PIPELINE", "1") == "1"

OJ_OBJECT_SETTINGS = { mode: :object, class_cache: true, symbol_keys: true }
OJ_COMPAT_DUMP_SETTINGS = { mode: :compat }
OJ_COMPAT_LOAD_SETTINGS = { mode: :compat, symbol_keys: true }
OJ_STRICT_DUMP_SETTINGS = { mode: :strict }
OJ_STRICT_LOAD_SETTINGS = { mode: :strict, symbol_keys: true }

# mirrors Migrations::Conversion::StepStats
StepStats = Struct.new(:progress, :warning_count, :error_count)

module Codecs
  # today's Worker implementation
  class OjObject
    def name = "Oj :object"

    def dump(data) = Oj.dump(data, OJ_OBJECT_SETTINGS)
    def load(string) = Oj.load(string, OJ_OBJECT_SETTINGS)

    def write(io, data) = Oj.to_stream(io, data, OJ_OBJECT_SETTINGS)
    def each(io, &) = Oj.load(io, OJ_OBJECT_SETTINGS, &)
  end

  class OjCompat
    def name = "Oj :compat"

    def dump(data) = Oj.dump(data, OJ_COMPAT_DUMP_SETTINGS)
    def load(string) = Oj.load(string, OJ_COMPAT_LOAD_SETTINGS)

    def write(io, data) = Oj.to_stream(io, data, OJ_COMPAT_DUMP_SETTINGS)
    def each(io, &) = Oj.load(io, OJ_COMPAT_LOAD_SETTINGS, &)
  end

  # like OjCompat, but raises TypeError if a non-primitive value leaks into a
  # payload -- the enforcing option for a primitive-only wire contract
  class OjStrict
    def name = "Oj :strict"

    def dump(data) = Oj.dump(data, OJ_STRICT_DUMP_SETTINGS)
    def load(string) = Oj.load(string, OJ_STRICT_LOAD_SETTINGS)

    def write(io, data) = Oj.to_stream(io, data, OJ_STRICT_DUMP_SETTINGS)
    def each(io, &) = Oj.load(io, OJ_STRICT_LOAD_SETTINGS, &)
  end

  class JsonLines
    def name = "JSON (NDJSON)"

    def dump(data) = JSON.generate(data)
    def load(string) = JSON.parse(string, symbolize_names: true)

    def write(io, data) = io.write(JSON.generate(data) << "\n")

    def each(io)
      io.each_line { |line| yield JSON.parse(line, symbolize_names: true) }
    end
  end

  # rubocop:disable Security/MarshalLoad -- benchmark data comes from our own
  # fork; the trust level matches today's Oj `:object` mode
  class RubyMarshal
    def name = "Marshal"

    def dump(data) = ::Marshal.dump(data)
    def load(string) = ::Marshal.load(string)

    def write(io, data) = ::Marshal.dump(data, io)

    def each(io)
      loop { yield ::Marshal.load(io) }
    rescue EOFError
      nil
    end
  end
  # rubocop:enable Security/MarshalLoad

  class Msgpack
    def name = "msgpack"

    def dump(data) = MessagePack.pack(data)
    def load(string) = MessagePack.unpack(string, symbolize_keys: true)

    def write(io, data) = io.write(MessagePack.pack(data))

    def each(io, &)
      MessagePack::Unpacker.new(io, symbolize_keys: true).each(&)
    end
  end
end

module Payloads
  # ~32 fields, shaped like the `users` step item (SELECT u.* plus avatar
  # columns): several timestamps, a date, two inet columns, realistic string
  # lengths, many nils
  def self.users_item(i, primitive:)
    created_at = Time.utc(2019, 12, 31, 23, 59, 59) + i
    last_seen_at = created_at + 86_400
    ip = IPAddr.new(i % 0xffffffff, Socket::AF_INET)

    {
      id: i + 1,
      username: "user_#{i}",
      name: "User Number #{i} von Üsername 😀",
      active: true,
      admin: false,
      moderator: false,
      staged: false,
      approved: true,
      approved_at: temporal(created_at, primitive:),
      approved_by_id: 1,
      created_at: temporal(created_at, primitive:),
      updated_at: temporal(last_seen_at, primitive:),
      first_seen_at: temporal(created_at, primitive:),
      last_seen_at: temporal(last_seen_at, primitive:),
      last_posted_at: nil,
      last_emailed_at: temporal(last_seen_at, primitive:),
      previous_visit_at: nil,
      suspended_at: nil,
      suspended_till: nil,
      silenced_till: nil,
      date_of_birth: primitive ? "1990-04-01" : Date.new(1990, 4, 1),
      ip_address: primitive ? ip.to_s : ip,
      registration_ip_address: primitive ? ip.to_s : ip,
      locale: nil,
      title: i % 10 == 0 ? "Trust Level 3 Member" : nil,
      trust_level: i % 5,
      group_locked_trust_level: nil,
      manual_locked_trust_level: nil,
      primary_group_id: nil,
      flair_group_id: nil,
      seen_notification_id: i * 7,
      uploaded_avatar_id: i % 3 == 0 ? i + 1000 : nil,
      views: i % 1234,
      avatar_url: "/uploads/default/original/3X/a/b/avatar_#{i}.png",
      avatar_filename: "avatar_#{i}.png",
      avatar_origin: nil,
      avatar_user_id: i + 1,
    }
  end

  # shaped like a site-settings step item carrying a nested JSONB-derived
  # array of hashes plus a timestamp
  def self.site_settings_item(i, primitive:)
    updated_at = Time.utc(2023, 5, 17, 12, 34, 56) + i

    {
      name: "setting_name_#{i}",
      value: "some moderately long setting value, number #{i}, with text",
      data_type: i % 25,
      updated_at: temporal(updated_at, primitive:),
      uploads: [
        {
          id: i + 1,
          url: "/uploads/default/original/3X/c/d/upload_#{i}.png",
          filename: "upload_#{i}.png",
          origin: nil,
          user_id: 1,
        },
        {
          id: i + 2,
          url: "/uploads/default/original/3X/e/f/upload_#{i + 1}.png",
          filename: "upload_#{i + 1}.png",
          origin: "https://example.com/upload_#{i + 1}.png",
          user_id: 1,
        },
      ],
    }
  end

  # the child -> parent payload: `[parametrized_insert_statements, stats]` as
  # produced by `ParallelJob#run` -- params are already primitives in all arms
  # because IntermediateDB models format values before insert
  def self.return_payload(struct_stats:)
    iso = "2019-12-31T23:59:59Z"
    statements = [
      [
        "INSERT INTO users (original_id, username, name, active, admin, moderator, staged, " \
          "approved, approved_at, approved_by_id, created_at, first_seen_at, last_seen_at, " \
          "silenced_till, suspended_at, suspended_till, date_of_birth, ip_address, " \
          "registration_ip_address, locale, title, trust_level, primary_group_id, " \
          "flair_group_id, uploaded_avatar_id, avatar_type, views) " \
          "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [
          42,
          "user_42",
          "User Number 42",
          1,
          0,
          0,
          0,
          1,
          iso,
          1,
          iso,
          iso,
          iso,
          nil,
          nil,
          nil,
          "1990-04-01",
          "192.168.0.1",
          nil,
          nil,
          nil,
          2,
          nil,
          nil,
          1042,
          1,
          1234,
        ],
      ],
      [
        "INSERT INTO user_emails (user_id, email, \"primary\", created_at) VALUES (?, ?, ?, ?)",
        [42, "user_42@example.com", 1, iso],
      ],
      [
        "INSERT INTO user_options (user_id, timezone, email_level, email_messages_level, " \
          "email_digests, hide_profile_and_presence, dark_scheme_id, color_scheme_id) " \
          "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        [42, "Europe/Vienna", 1, 1, 1, 0, nil, nil],
      ],
    ]

    stats = StepStats.new(1, 0, 0)
    [statements, struct_stats ? stats : stats.to_a]
  end

  def self.temporal(time, primitive:)
    # under a primitive wire format, timestamps cross as PG text
    primitive ? time.strftime("%F %T") : time
  end

  def self.corpus(builder, primitive:)
    unique = UNIQUE_ITEM_COUNT.times.map { |i| public_send(builder, i, primitive:) }
    (ITEM_COUNT / UNIQUE_ITEM_COUNT.to_f).ceil.times.flat_map { unique }.first(ITEM_COUNT)
  end
end

# replicates the fork + IO.pipe + thread structure of
# `Migrations::Conversion::Worker#start`, including its one-item-in-flight
# handshake, with the codec injected
#
# The sent/processed counters below match the handshake fixed in #40826:
# `Worker` originally waited on its condition variable without a predicate,
# which loses the wakeup when the child's response arrives before the input
# thread reaches `wait`. With a real job that window is rarely hit, but this
# benchmark's no-op child hits it within a few hundred thousand messages and
# hangs forever.
class PipelineBenchmark
  STALL_TIMEOUT = 30 # seconds without progress -> abort the run

  # window: max unacknowledged messages in flight; 1 reproduces `Worker`'s
  # current lockstep handshake
  def initialize(codec, items, result_payload, window: 1)
    @codec = codec
    @items = items
    @result_payload = result_payload
    @window = window
  end

  def run
    input_queue = Queue.new
    @items.each { |item| input_queue << item }
    input_queue.close

    sent_count = 0
    output_count = 0
    mutex = Mutex.new
    data_processed = ConditionVariable.new

    parent_input_stream, parent_output_stream = IO.pipe
    fork_input_stream, fork_output_stream = IO.pipe

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    worker_pid =
      Process.fork do
        parent_output_stream.close
        fork_input_stream.close

        @codec.each(parent_input_stream) do |_data|
          @codec.write(fork_output_stream, @result_payload)
        end

        fork_output_stream.close
        exit!(0)
      end

    fork_output_stream.close
    parent_input_stream.close

    input_thread =
      Thread.new do
        while (data = input_queue.pop)
          @codec.write(parent_output_stream, data)
          sent_count += 1
          mutex.synchronize do
            data_processed.wait(mutex) while sent_count - output_count >= @window
          end
        end
      ensure
        parent_output_stream.close
        Process.waitpid(worker_pid)
      end

    output_thread =
      Thread.new do
        @codec.each(fork_input_stream) do |_data|
          mutex.synchronize do
            output_count += 1
            data_processed.signal
          end
        end
      ensure
        fork_input_stream.close
        mutex.synchronize { data_processed.signal }
      end

    watchdog_thread =
      Thread.new do
        last_count = 0
        last_progress_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        while input_thread.alive? || output_thread.alive?
          sleep(0.25)
          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          if output_count > last_count
            last_count = output_count
            last_progress_at = now
          elsif now - last_progress_at > STALL_TIMEOUT
            begin
              Process.kill("KILL", worker_pid)
            rescue Errno::ESRCH
              nil
            end
            [input_thread, output_thread].each(&:kill)
            raise "#{@codec.name}: pipeline stalled at #{output_count}/#{@items.size} messages"
          end
        end
      end

    [input_thread, output_thread].each(&:join)
    # measure before joining the watchdog -- its sleep interval must not
    # quantize the result
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
    watchdog_thread.join

    raise "lost messages: #{output_count}/#{@items.size}" if output_count != @items.size
    elapsed
  end
end

CODEC_A = Codecs::OjObject.new
CODEC_B = Codecs::OjCompat.new
CODEC_C = Codecs::JsonLines.new
CODEC_D = Codecs::RubyMarshal.new
CODEC_E = Codecs::Msgpack.new
CODEC_F = Codecs::OjStrict.new

ARMS = [
  ["A: #{CODEC_A.name} (today)", CODEC_A, { primitive: false, struct_stats: true }],
  ["B: #{CODEC_B.name} + primitives", CODEC_B, { primitive: true, struct_stats: false }],
  ["C: #{CODEC_C.name} + primitives", CODEC_C, { primitive: true, struct_stats: false }],
  ["D: #{CODEC_D.name} (today's payloads)", CODEC_D, { primitive: false, struct_stats: true }],
  ["E: #{CODEC_E.name} + primitives", CODEC_E, { primitive: true, struct_stats: false }],
  ["F: #{CODEC_F.name} + primitives", CODEC_F, { primitive: true, struct_stats: false }],
]

puts "",
     RUBY_DESCRIPTION,
     "YJIT enabled: #{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?}",
     "oj #{Oj::VERSION}, json #{JSON::VERSION}, msgpack #{MessagePack::VERSION}, pg #{PG::VERSION}",
     "items per pipeline run: #{ITEM_COUNT} (#{UNIQUE_ITEM_COUNT} unique)",
     ""

# sanity check: every codec must round-trip its own payloads losslessly
ARMS.each do |name, codec, options|
  %i[users_item site_settings_item].each do |builder|
    payload = Payloads.public_send(builder, 1, primitive: options[:primitive])
    raise "#{name} does not round-trip #{builder}" if codec.load(codec.dump(payload)) != payload
  end

  return_payload = Payloads.return_payload(struct_stats: options[:struct_stats])
  loaded = codec.load(codec.dump(return_payload))
  loaded[1] = StepStats.new(*loaded[1]) if !options[:struct_stats]
  expected = return_payload.dup.tap { |p| p[1] = StepStats.new(*p[1]) if !options[:struct_stats] }
  raise "#{name} does not round-trip return_payload" if loaded != expected
end

if RUN_MICRO
  puts "=== Micro: serialize + deserialize in-process ==="

  {
    "users item" => :users_item,
    "site-settings item" => :site_settings_item,
  }.each do |label, builder|
    Benchmark.ips do |x|
      x.config(time: 10, warmup: 2)

      ARMS.each do |name, codec, options|
        payload = Payloads.public_send(builder, 1, primitive: options[:primitive])
        x.report("#{label} | #{name}") { codec.load(codec.dump(payload)) }
      end

      x.compare!
    end
  end

  Benchmark.ips do |x|
    x.config(time: 10, warmup: 2)

    ARMS.each do |name, codec, options|
      payload = Payloads.return_payload(struct_stats: options[:struct_stats])
      x.report("return path | #{name}") { codec.load(codec.dump(payload)) }
    end

    x.compare!
  end

  puts "", "=== Temporal handling: where does Time -> string conversion happen? ==="

  pg_timestamp_text = "2023-05-17 12:34:56.789123"
  pg_timestamp_decoder = PG::TextDecoder::TimestampLocal.new
  the_time = Time.utc(2023, 5, 17, 12, 34, 56)

  Benchmark.ips do |x|
    x.config(time: 10, warmup: 2)

    x.report("today: Time#utc.iso8601") { the_time.utc.iso8601 }
    x.report("strategy A: Time.parse(pg_text).utc.iso8601 (worker-side)") do
      Time.parse(pg_timestamp_text).utc.iso8601
    end
    x.report("strategy B: PG::TextDecoder + utc.iso8601 (parent-side)") do
      pg_timestamp_decoder.decode(pg_timestamp_text).utc.iso8601
    end

    x.compare!
  end
end

if RUN_PIPELINE
  puts "", "=== Pipeline: fork + IO.pipe end-to-end (the number that matters) ==="

  {
    "users corpus" => :users_item,
    "site-settings corpus" => :site_settings_item,
  }.each do |label, builder|
    puts "", "--- #{label} ---"

    arms =
      ARMS.map do |name, codec, options|
        items = Payloads.corpus(builder, primitive: options[:primitive])
        result_payload = Payloads.return_payload(struct_stats: options[:struct_stats])
        [name, codec, items, result_payload]
      end

    PIPELINE_WINDOWS.each do |window|
      puts "window #{window}:"

      # a stalled or lossy arm must not abort the whole benchmark -- record
      # the failure and keep measuring the others
      failures = {}

      run_arm = ->(name, codec, items, result_payload) do
        PipelineBenchmark.new(codec, items, result_payload, window:).run
      rescue RuntimeError => e
        failures[name] ||= e.message
        nil
      end

      # warmup each arm with a slice of the corpus
      arms.each do |name, codec, items, result_payload|
        run_arm.call(name, codec, items.first(ITEM_COUNT / 10), result_payload)
      end

      # interleave the arms round-robin so CPU frequency / scheduling drift
      # hits all arms equally instead of biasing whichever arm ran last
      runs = Hash.new { |hash, key| hash[key] = [] }
      PIPELINE_RUNS_PER_ARM.times do
        arms.each do |name, codec, items, result_payload|
          next if failures[name]
          elapsed = run_arm.call(name, codec, items, result_payload)
          runs[name] << elapsed if elapsed
        end
      end

      arms.each do |name, *|
        if (failure = failures[name])
          puts format("%-38s FAILED: %s", name, failure)
        else
          best = runs[name].min
          puts format(
                 "%-38s best %7.3f s  %8d items/sec  (runs: %s)",
                 name,
                 best,
                 (ITEM_COUNT / best).round,
                 runs[name].map { |elapsed| format("%.3f", elapsed) }.join(" / "),
               )
        end
      end
    end
  end
end
