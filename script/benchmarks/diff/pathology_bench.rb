# frozen_string_literal: true

require "json"
require "optparse"
require "time"

$LOAD_PATH.unshift(File.expand_path("../../../lib", __dir__))

require "onpdiff"

class DiffPathologyBench
  DEFAULT_SIZES = [250, 500, 1000, 2000, 4000]
  DEFAULT_CASES = %w[
    identical
    sparse_edits
    middle_insert
    full_replace
    random_tokens
    shifted
    alternating
  ].freeze
  DEFAULT_REPETITIONS = 3
  DEFAULT_FACTOR = ONPDiff::DEFAULT_COMPARISON_BUDGET_FACTOR
  DEFAULT_CEILING = ONPDiff::MAX_COMPARISON_BUDGET
  DEFAULT_JSON_OUT = "tmp/diff_pathology_bench.json"

  def self.run!(argv = ARGV)
    options = {
      sizes: DEFAULT_SIZES.dup,
      cases: DEFAULT_CASES.dup,
      repetitions: DEFAULT_REPETITIONS,
      factor: DEFAULT_FACTOR,
      ceiling: DEFAULT_CEILING,
      json_out: DEFAULT_JSON_OUT,
    }

    parser =
      OptionParser.new do |opts|
        opts.banner = "Usage: ruby script/benchmarks/diff/pathology_bench.rb [options]"

        opts.on(
          "--sizes LIST",
          String,
          "Comma-separated sizes (default: #{DEFAULT_SIZES.join(",")})",
        ) { |value| options[:sizes] = value.split(",").map(&:strip).reject(&:empty?).map(&:to_i) }

        opts.on(
          "--cases LIST",
          String,
          "Comma-separated case names (default: #{DEFAULT_CASES.join(",")})",
        ) { |value| options[:cases] = value.split(",").map(&:strip).reject(&:empty?) }

        opts.on(
          "--repetitions N",
          Integer,
          "Runs per case/size pair (default: #{DEFAULT_REPETITIONS})",
        ) { |value| options[:repetitions] = value }

        opts.on(
          "--factor N",
          Integer,
          "Comparison budget factor (default: #{DEFAULT_FACTOR})",
        ) { |value| options[:factor] = value }

        opts.on(
          "--ceiling N",
          Integer,
          "Comparison budget ceiling (default: #{DEFAULT_CEILING})",
        ) { |value| options[:ceiling] = value }

        opts.on(
          "--json-out PATH",
          String,
          "Write JSON results to path (default: #{DEFAULT_JSON_OUT})",
        ) { |value| options[:json_out] = value }

        opts.on("--list-cases", "List supported pathology cases") do
          puts DEFAULT_CASES.join("\n")
          exit 0
        end
      end

    parser.parse!(argv)

    options[:cases].each do |case_name|
      next if DEFAULT_CASES.include?(case_name)
      raise ArgumentError, "Unknown case '#{case_name}'. Use --list-cases to see valid values."
    end

    raise ArgumentError, "--sizes must not be empty" if options[:sizes].empty?
    raise ArgumentError, "--cases must not be empty" if options[:cases].empty?
    raise ArgumentError, "--repetitions must be >= 1" if options[:repetitions] < 1
    raise ArgumentError, "--factor must be >= 1" if options[:factor] < 1
    raise ArgumentError, "--ceiling must be >= 1" if options[:ceiling] < 1

    bench = new(options)
    results = bench.run
    bench.print_table(results)
    bench.write_json(results)
  end

  def initialize(options)
    @sizes = options[:sizes]
    @cases = options[:cases]
    @repetitions = options[:repetitions]
    @factor = options[:factor]
    @ceiling = options[:ceiling]
    @json_out = options[:json_out]
  end

  def run
    @sizes.flat_map { |size| @cases.map { |case_name| benchmark_case(case_name, size) } }
  end

  def print_table(results)
    puts "ONPDiff pathology benchmark"
    puts "factor=#{@factor} ceiling=#{@ceiling} repetitions=#{@repetitions}"
    puts

    header = %w[case size limits avg_ms max_ms max_cmp budget max_use%]
    puts format("%-14s %6s %8s %10s %10s %12s %12s %9s", *header)
    puts "-" * 92

    results.each do |result|
      puts format(
             "%-14s %6d %8s %10.3f %10.3f %12d %12d %8.2f",
             result[:case],
             result[:size],
             "#{result[:limit_exceeded_runs]}/#{result[:repetitions]}",
             result[:avg_elapsed_ms],
             result[:max_elapsed_ms],
             result[:max_comparisons_used],
             result[:comparison_budget],
             result[:max_budget_used_percent],
           )
    end

    puts
    puts "JSON report: #{@json_out}"
  end

  def write_json(results)
    payload = {
      generated_at: Time.now.utc.iso8601,
      factor: @factor,
      ceiling: @ceiling,
      sizes: @sizes,
      cases: @cases,
      repetitions: @repetitions,
      results: results,
    }

    dir = File.dirname(@json_out)
    Dir.mkdir(dir) unless dir == "." || Dir.exist?(dir)
    File.write(@json_out, JSON.pretty_generate(payload))
  end

  private

  def benchmark_case(case_name, size)
    runs =
      Array.new(@repetitions) do |index|
        before, after = build_case(case_name, size, index)

        diff =
          ONPDiff.new(
            before,
            after,
            comparison_budget_factor: @factor,
            max_comparison_budget: @ceiling,
          )

        status = "ok"
        output_size = nil
        error = nil
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        begin
          output_size = diff.diff.size
        rescue ONPDiff::DiffLimitExceeded => exception
          status = "limit_exceeded"
          error = exception.message
        end

        elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000.0

        {
          status: status,
          elapsed_ms: elapsed_ms.round(6),
          comparisons_used: diff.comparisons_used,
          comparison_budget: diff.comparison_budget,
          budget_used_percent:
            if diff.comparison_budget == 0
              0.0
            else
              (diff.comparisons_used.to_f / diff.comparison_budget * 100.0).round(6)
            end,
          output_size: output_size,
          error: error,
        }
      end

    {
      case: case_name,
      size: size,
      repetitions: @repetitions,
      limit_exceeded_runs: runs.count { |run| run[:status] == "limit_exceeded" },
      avg_elapsed_ms: average(runs.map { |run| run[:elapsed_ms] }).round(6),
      max_elapsed_ms: runs.map { |run| run[:elapsed_ms] }.max.round(6),
      avg_comparisons_used: average(runs.map { |run| run[:comparisons_used] }).round(2),
      max_comparisons_used: runs.map { |run| run[:comparisons_used] }.max,
      comparison_budget: runs.first[:comparison_budget],
      max_budget_used_percent: runs.map { |run| run[:budget_used_percent] }.max.round(6),
      max_output_size: runs.filter_map { |run| run[:output_size] }.max,
      runs: runs,
    }
  end

  def build_case(case_name, size, index)
    rng = Random.new((size * 1000) + index)

    case case_name
    when "identical"
      tokens = sequence_tokens(size, "token")
      [tokens, tokens.dup]
    when "sparse_edits"
      before = sequence_tokens(size, "token")
      after = before.dup
      step = [size / 20, 1].max
      (0...size).step(step) { |idx| after[idx] = "edited_#{idx}" }
      [before, after]
    when "middle_insert"
      before = sequence_tokens(size, "token")
      insert_count = [size / 2, 1].max
      middle = before.length / 2
      after = before.dup
      after.insert(middle, *sequence_tokens(insert_count, "insert"))
      [before, after]
    when "full_replace"
      [sequence_tokens(size, "before"), sequence_tokens(size, "after")]
    when "random_tokens"
      [random_tokens(size, rng), random_tokens(size, rng)]
    when "shifted"
      before = sequence_tokens(size, "token")
      [before, before.rotate(1)]
    when "alternating"
      before = Array.new(size) { |idx| idx.even? ? "A" : "B" }
      after = Array.new(size) { |idx| idx.even? ? "B" : "A" }
      [before, after]
    else
      raise ArgumentError, "Unknown case '#{case_name}'"
    end
  end

  def sequence_tokens(size, prefix)
    Array.new(size) { |idx| "#{prefix}_#{idx}" }
  end

  def random_tokens(size, rng)
    Array.new(size) { format("%08x", rng.rand(0xFFFF_FFFF)) }
  end

  def average(values)
    values.sum.to_f / values.size
  end
end

DiffPathologyBench.run!
