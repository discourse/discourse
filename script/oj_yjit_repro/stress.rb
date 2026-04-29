# frozen_string_literal: true
# Stress harness for the suspected oj 3.16.13 + YJIT crash.
#
# Crash signature we're chasing:
#   YJIT panic: assert_ne! in yjit::cruby::VALUE::class_of, called from
#   gen_opt_aref, while Ruby was running an as_json invoked by oj's
#   rails encoder (rails.c:dump_as_json).
#
# Strategy:
#   - oj rails encoder, lots of nested arrays (matches the rb_ary_each
#     levels in the prod stack trace).
#   - Wide variety of as_json receiver classes — forces YJIT to keep
#     re-specializing class_of for opt_aref call sites.
#   - Each as_json hits many different opt_aref shapes (Hash[Symbol],
#     Hash[String], Array[Integer], Array[neg], String[idx], nested).
#   - Concurrent encoders to maximize timing variance.
#
# Run (Linux x86_64, matching prod):
#   cd /tmp/oj_yjit_repro && bundle install
#   ulimit -c unlimited
#   RUBY_YJIT_ENABLE=1 bundle exec ruby stress.rb
#
# Controls:
#   THREADS=16 ...                 # concurrency (default 8)
#   RUBY_YJIT_ENABLE=0 ...         # YJIT off — should NOT crash
#   edit Gemfile to oj 3.16.12     # SIMD off — should NOT crash if oj is the cause
#
# Leave this running for hours. The prod crash is "once in a while".

require "oj"
Oj.optimize_rails

NUM_CLASSES = 64
NUM_THREADS = (ENV["THREADS"] || "8").to_i

CLASSES =
  NUM_CLASSES.times.map do |i|
    Class.new do
      define_method(:initialize) do |seed|
        @seed = seed
        @hash = { a: 1, b: "two", c: [3, 4, 5], d: { nested: true } }
        @arr = (0..9).to_a
        @str = "abcdefghij"
        @kls = i
      end

      define_method(:as_json) do |*|
        {
          h_sym: @hash[:a],
          h_str: @hash["a".freeze],
          h_nested: @hash[:c][1],
          a_idx: @arr[@kls % @arr.size],
          a_neg: @arr[-1],
          s_idx: @str[2],
          seed: (@seed.is_a?(Array) ? @seed[0] : @seed),
          deep: @hash[:d][:nested],
        }
      end
    end
  end

def make_payload
  Array.new(20) do
    Array.new(10) do
      Array.new(4) do
        CLASSES.sample.new(rand < 0.5 ? [rand(1000), rand(1000)] : "s#{rand(10_000)}")
      end
    end
  end
end

ops = Array.new(NUM_THREADS, 0)

NUM_THREADS.times.map do |tid|
  Thread.new do
    payload = make_payload
    loop do
      Oj.dump(payload, mode: :rails)
      ops[tid] += 1
      payload = make_payload if (ops[tid] & 0x3ff).zero?
    end
  end
end

trap("INT") do
  puts
  puts "stopped at #{ops.sum} dumps"
  exit 0
end

yjit = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
puts "yjit=#{yjit} threads=#{NUM_THREADS} oj=#{Oj::VERSION} ruby=#{RUBY_VERSION}"

start = Time.now
loop do
  sleep 10
  total = ops.sum
  elapsed = Time.now - start
  printf("[%4ds] dumps=%d (~%d/s)\n", elapsed.to_i, total, (total / elapsed).to_i)
end
