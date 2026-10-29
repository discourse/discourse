# frozen_string_literal: true

require "bundler/setup"
require "json"
require "fileutils"

module RspecSelection
  DIRECTORY = "tmp/rspec-mapping"

  def self.merge
    workers = Dir["#{DIRECTORY}/worker-*.json"].map { |file| JSON.parse(File.read(file)) }
    revision = ENV.fetch("GITHUB_SHA")
    manifest = JSON.parse(File.read("#{DIRECTORY}/execution.json"))
    valid =
      manifest["revision"] == revision && workers.any? &&
        manifest
          .fetch("workers")
          .all? do |identity, files|
            workers.any? do |worker|
              worker["identity"] == identity && worker["files"].sort == files.sort
            end
          end
    valid &&=
      workers.all? do |worker|
        order = worker["spec_order"]
        worker["version"] == 4 && worker["complete"] && worker["revision"] == revision &&
          order.is_a?(Array) && order.all? { |spec| spec.is_a?(String) } &&
          order.length == worker["completed_groups"] &&
          order.uniq.sort == worker.fetch("dependencies").keys.sort
      end
    unless valid
      workers.each do |worker|
        warn JSON.generate(
               worker.slice(
                 "identity",
                 "complete",
                 "completed_groups",
                 "expected_groups",
                 "input_failure",
                 "non_example_failure",
               ),
             )
      end
      abort "Incomplete RSpec mapping"
    end

    require_relative "rspec_source_structure"
    dependencies = Hash.new { |mapping, spec| mapping[spec] = [] }
    boot_lines = Hash.new { |mapping, path| mapping[path] = [] }
    workers.each do |worker|
      worker.fetch("dependencies").each { |spec, sources| dependencies[spec] |= sources }
      worker.fetch("boot_lines").each { |path, lines| boot_lines[path] |= lines }
    end
    source_checks =
      dependencies
        .values
        .flatten
        .uniq
        .each_with_object({}) do |path, result|
          relative = path.delete_prefix("./")
          next unless relative.match?(%r{\A(app|lib)/.*\.rb\z}) && File.file?(relative)
          result[relative] = RspecSourceStructure.describe(
            relative,
            boot_lines: boot_lines[relative],
          )
        end
    File.write(
      "#{DIRECTORY}/mapping.json",
      JSON.generate(
        version: 4,
        revision:,
        grouping_runtime_log: manifest.fetch("grouping_runtime_log"),
        dependencies:,
        worker_specs:
          workers.map do |worker|
            if worker["identity"] == "multisite"
              worker.fetch("dependencies").keys
            else
              worker.fetch("files")
            end
          end,
        empty_specs: manifest.fetch("workers").values.flatten.uniq - dependencies.keys,
        source_checks:,
        shared_files: workers.flat_map { |worker| worker.fetch("shared_files") }.uniq,
        shared_globs: workers.flat_map { |worker| worker.fetch("shared_globs") }.uniq,
      ),
    )
  end

  def self.run
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    before = Process.times
    container_before = container_cpu_seconds
    FileUtils.mkdir_p(DIRECTORY)
    revision = ENV["GITHUB_SHA"]
    selection =
      begin
        parsed = JSON.parse(File.read("#{DIRECTORY}/selection.json"))
        parsed.is_a?(Hash) ? parsed : {}
      rescue Errno::ENOENT, JSON::ParserError
        {}
      end
    available_specs =
      Dir.glob("spec/**/*_spec.rb").reject { |spec| spec.start_with?("spec/system/") }.sort
    collecting = ENV["COLLECT_RSPEC_MAPPING"] == "1"
    subset =
      !collecting && revision && selection["mode"] == "subset" && selection["revision"] == revision
    reason = selection["reason"]
    if subset
      specs = selection["specs"]
      checks = selection["source_checks"]
      require_relative "rspec_source_structure"
      cohorts = selection["cohort_specs"]
      if !specs.is_a?(Array) || !cohorts.is_a?(Array) || (specs - available_specs).any? ||
           (cohorts - specs).any? || ![true, false].include?(selection["full_multisite"]) ||
           (cohorts.any? && !selection["full_multisite"])
        subset = false
        reason = "Invalid spec inventory"
      elsif !checks.is_a?(Hash) ||
            !checks.all? do |path, description|
              path.match?(%r{\A(app|lib)/.*\.rb\z}) && !path.split("/").include?("..") &&
                RspecSourceStructure.matches?(path:, description:)
            end
        subset = false
        reason = "Source structure changed or unavailable"
      end
    end
    auditing = subset && selection["audit"] == true
    mode =
      if auditing
        "audit"
      elsif subset
        "subset"
      else
        "full"
      end
    arguments = ["--execution-plan", "#{DIRECTORY}/execution.json"]
    arguments += ["--selection", "#{DIRECTORY}/selection.json"] if subset
    Dir["#{DIRECTORY}/worker-*.json"].each { |path| File.delete(path) } if collecting
    File.delete("#{DIRECTORY}/execution.json") if File.exist?("#{DIRECTORY}/execution.json")
    Dir["#{DIRECTORY}/audit-worker-*.json"].each { |path| File.delete(path) }
    puts "Core RSpec execution: #{mode}"
    success =
      if subset && !auditing && specs.empty? && !selection["full_multisite"]
        true
      else
        system(
          { "RSPEC_SELECTION_AUDIT" => auditing ? "1" : nil },
          "bin/turbo_rspec",
          "--use-runtime-info",
          "--format=progress",
          *arguments,
        )
      end
    child_status = $?
    status =
      if success
        0
      elsif child_status
        child_status.exitstatus || 128 + child_status.termsig
      else
        1
      end
    after = Process.times
    container_after = container_cpu_seconds
    execution =
      begin
        JSON.parse(File.read("#{DIRECTORY}/execution.json"))
      rescue Errno::ENOENT, JSON::ParserError
        {}
      end
    if !execution["workers"].is_a?(Hash) || execution["revision"] != revision
      unless subset && !auditing && specs.empty? && !selection["full_multisite"]
        status = 1
        reason = "Missing or stale execution plan"
      end
    end
    predicted_specs = execution["predicted_regular_specs"] || []
    if subset && (specs - predicted_specs).any?
      status = 1
      reason = "Execution plan omits selected specs"
    end
    report = {
      revision:,
      mode:,
      reason:,
      selection_seconds: selection["selection_seconds"],
      selection_cpu_seconds: selection["selection_cpu_seconds"],
      selection_cpu_scope: selection["selection_cpu_scope"],
      selected_files: subset ? predicted_specs.size : available_specs.size,
      selected_multisite_files: execution.fetch("predicted_multisite_specs", []).size,
      available_files: available_specs.size,
      wall_seconds: Process.clock_gettime(Process::CLOCK_MONOTONIC) - started,
      cpu_seconds:
        after.utime + after.stime + after.cutime + after.cstime - before.utime - before.stime -
          before.cutime - before.cstime,
      cpu_scope: "wrapper and child processes, excluding database and Redis services",
      container_cpu_seconds:
        container_before && container_after ? container_after - container_before : nil,
      container_cpu_scope: "cgroup namespace root, including all its processes",
      exit: status,
    }
    if auditing
      workers = Dir["#{DIRECTORY}/audit-worker-*.json"].map { |path| JSON.parse(File.read(path)) }
      files = workers.flat_map { |worker| worker.fetch("files") }.uniq.sort
      expected = execution.fetch("workers", {})
      complete =
        expected.any? && workers.any? && files == available_specs &&
          workers.all? { |worker| worker["complete"] } &&
          expected.all? do |identity, expected_files|
            workers.any? do |worker|
              worker["identity"] == identity && worker["files"].sort == expected_files.sort
            end
          end
      report[:audit_complete] = complete
      report[:audit_failures] = workers.flat_map { |worker| worker.fetch("failures") }.uniq
      report[:omitted_failures] = workers
        .flat_map { |worker| worker.fetch("omitted_failures") }
        .uniq
      unless complete
        warn "Incomplete RSpec selection audit, expected every assigned worker"
        status = 1
      end
      report[:exit] = status
    end
    File.write("#{DIRECTORY}/run.json", JSON.generate(report))
    puts JSON.generate(report)
    exit status
  end

  def self.container_cpu_seconds
    return unless File.read("/proc/self/cgroup").strip == "0::/"
    usage = File.read("/sys/fs/cgroup/cpu.stat")[/^usage_usec (\d+)$/, 1]
    usage && usage.to_i / 1_000_000.0
  rescue SystemCallError
    nil
  end
  private_class_method :container_cpu_seconds
end

case ARGV.fetch(0)
when "merge"
  RspecSelection.merge
when "run"
  RspecSelection.run
else
  abort "Expected merge or run"
end
