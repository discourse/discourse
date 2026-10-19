# frozen_string_literal: true
require "digest"
require "fileutils"
require "json"
require "open3"

FileUtils.mkdir_p("tmp")
command = %w[bin/turbo_rspec --use-runtime-info --format documentation spec/system]
runtime_sha256 = Digest::SHA256.file("tmp/turbo_rspec_runtime.log").hexdigest
unless runtime_sha256 == "6a24ebba9fc72daf2b54ce8c846562a9c251b22b9450b6a2d5e6f8424f5e3fe1"
  raise "Scheduling input changed"
end

started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
status = nil
File.open("tmp/core-system-comparison.log", "w") do |log|
  Open3.popen2e(*command) do |stdin, output, process|
    stdin.close
    output.each_line do |line|
      $stdout.write(line)
      log.write(line)
    end
    status = process.value
  end
end
elapsed_seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
log = File.read("tmp/core-system-comparison.log").gsub(/\e\[[0-9;]*m/, "")
reasons = []
reasons << "Test command failed" unless status.success?
unless log.match?(/\b2334 examples, 0 failures, 2 pending\b/)
  reasons << "Unexpected example count or failures"
end
if log.include?("Retrying failed examples and logging flaky tests...")
  reasons << "Examples were retried"
end
if log.include?("DIRECT_MEASUREMENT_RETRY=")
  reasons << "A full matcher wait or MessageBus recovery occurred"
end
audits =
  log.lines.filter_map do |line|
    if line.include?("DIRECT_MEASUREMENT_RETRY_AUDIT=")
      JSON.parse(line.split("DIRECT_MEASUREMENT_RETRY_AUDIT=", 2).last)
    end
  end
worker_count = Integer(ENV.fetch("PARALLEL_TEST_PROCESSORS"))
unless audits.size == worker_count + 1 && audits.all? { |audit| audit["count"] == 0 }
  reasons << "Missing clean wait audits"
end
scopes = Dir["tmp/direct-worker-scope/*.json"].map { |path| JSON.parse(File.read(path)) }
regular_scopes = scopes.reject { |scope| scope["worker"] == "multisite" }
files = regular_scopes.flat_map { |scope| scope["files"] }
unless files.size == 298 && files.uniq.size == 298 && regular_scopes.size == worker_count &&
         scopes.size == worker_count + 1
  reasons << "Missing or duplicated core spec files"
end
expected_adapter = ENV.fetch("CORE_SYSTEM_VARIANT") == "baseline"
unless scopes.all? { |scope|
         scope["adapter_loaded"] == expected_adapter &&
           scope["adapter_page_hook"] == expected_adapter
       }
  reasons << "Wrong browser integration"
end
flaky_path = "tmp/turbo_rspec_flaky_tests.json"
if File.exist?(flaky_path) && !JSON.parse(File.read(flaky_path)).empty?
  reasons << "Flaky examples were logged"
end
result = {
  variant: ENV.fetch("CORE_SYSTEM_VARIANT"),
  baseline: "ef39767ea7f0af060f6f182c2fd8b391e6dbc2e5",
  head: ENV.fetch("GITHUB_SHA"),
  run_id: ENV.fetch("GITHUB_RUN_ID"),
  run_attempt: ENV.fetch("GITHUB_RUN_ATTEMPT"),
  command: command,
  elapsed_seconds: elapsed_seconds,
  exit_code: status.exitstatus,
  valid: reasons.empty?,
  invalid_reasons: reasons,
  runtime_input_sha256: runtime_sha256,
  log_sha256: Digest::SHA256.file("tmp/core-system-comparison.log").hexdigest,
  processors: worker_count,
  ruby: RUBY_VERSION,
  worker_scopes: scopes,
}
File.write("tmp/core-system-comparison.json", JSON.pretty_generate(result))
File.open(ENV.fetch("GITHUB_STEP_SUMMARY"), "a") do |summary|
  summary.puts "### Core system tests: #{result[:variant]}"
  summary.puts
  summary.puts "#{elapsed_seconds.round(1)} seconds. Valid comparison: #{result[:valid]}."
  reasons.each { |reason| summary.puts "\n* #{reason}" }
end
warn reasons.join("\n") unless reasons.empty?
exit(reasons.empty? ? 0 : 1)
