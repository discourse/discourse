# frozen_string_literal: true
require "json"
require "fileutils"
require_relative "dependency_graph"

module TestSelection
  class Planner
    def initialize(input)
      @input = input
      @jobs = input.fetch("jobs")
      @changes = input.fetch("changes")
      @test_changes = input.fetch("test_changes")
      @deleted_tests = input.fetch("deleted_tests")
      validate!
    end

    def plan
      reasons = Hash.new { |hash, file| hash[file] = [] }
      inventory = @jobs.values.flat_map { |job| job.fetch("inventory") }.uniq.sort
      global_inventory = @input.fetch("global_inventory", inventory)
      @test_changes.each do |file|
        next if @deleted_tests.include?(file)
        unless global_inventory.include?(file)
          raise ArgumentError, "Changed test has no current owner: #{file}"
        end
        reasons[file] << "Changed test: #{file}" if inventory.include?(file)
      end
      full = @input.fetch("main") || @input.fetch("mode") == "full"
      input_changes = @changes - @test_changes
      application_changes = input_changes.reject { |path| documentation?(path) }
      @jobs.each do |name, job|
        shared_inputs = job["mapping"].is_a?(Hash) ? job["mapping"]["shared_files"] : nil
        if full
          job.fetch("inventory").each { |file| reasons[file] << "Full execution requested" }
        elsif job.fetch("shared_test_changes", []).any?
          job
            .fetch("shared_test_changes")
            .each do |path|
              job
                .fetch("inventory")
                .each { |file| reasons[file] << "Shared test setup changed: #{path}" }
            end
        elsif application_changes.any? ||
              (
                input_changes.any? &&
                  job.fetch("mapping_changes").any? { |path| !documentation?(path) }
              ) ||
              (
                shared_inputs.is_a?(Array) &&
                  ((@changes + job.fetch("mapping_changes")) & shared_inputs).any?
              )
          select_dependencies(name: name, job: job, reasons: reasons)
        end
      end
      selected = reasons.keys.sort
      {
        "version" => 2,
        "revision" => @input.fetch("revision"),
        "mode" => full ? "full" : @input.fetch("mode"),
        "files" => selected,
        "reasons" => reasons.transform_values(&:uniq),
        "environments" => @jobs.transform_values { |job| job.fetch("environment") },
        "jobs" =>
          @jobs.transform_values do |job|
            job.fetch("inventory").select { |file| reasons.key?(file) }
          end,
      }
    end

    private

    def documentation?(path)
      path.start_with?("docs/") || (!path.include?("/") && path.end_with?(".md"))
    end

    def validate!
      unless @input.fetch("revision").match?(/\A[0-9a-f]{40}\z/) &&
               %w[full audit select].include?(@input.fetch("mode")) &&
               [true, false].include?(@input.fetch("main")) && @jobs.is_a?(Hash) && !@jobs.empty?
        raise ArgumentError, "Invalid plan identity or mode"
      end
      [@changes, @test_changes, @deleted_tests].each { |paths| validate_paths!(paths) }
      validate_paths!(@input.fetch("global_inventory")) if @input.key?("global_inventory")
      unless (@test_changes - @changes).empty? && (@deleted_tests - @test_changes).empty?
        raise ArgumentError, "Test changes must belong to the PR changeset"
      end
      @jobs.each do |name, job|
        raise ArgumentError, "Invalid job identity" unless name.is_a?(String) && !name.empty?
        validate_paths!(job.fetch("inventory"))
        validate_paths!(job.fetch("mapping_changes"))
        validate_paths!(job.fetch("verified_sources"))
        validate_paths!(job.fetch("shared_test_changes", []))
        validate_paths!(job.fetch("mapping_shared_test_changes", []))
        unless (job.fetch("shared_test_changes", []) - @test_changes).empty?
          raise ArgumentError, "Shared test setup must belong to the test changeset"
        end
        unless (job.fetch("mapping_shared_test_changes", []) - job.fetch("mapping_changes")).empty?
          raise ArgumentError, "Mapping setup changes must belong to the mapping history"
        end
        unless job.fetch("inventory").uniq == job.fetch("inventory")
          raise ArgumentError, "Duplicate test inventory"
        end
        unless job.fetch("environment").is_a?(String)
          raise ArgumentError, "Missing environment identity"
        end
      end
    end

    def validate_paths!(paths)
      unless paths.is_a?(Array) &&
               paths.all? { |path|
                 path.is_a?(String) && !path.empty? && !path.include?("\0") &&
                   !path.include?("\\") &&
                   path.split("/", -1).none? { |part| ["", ".", ".."].include?(part) }
               }
        raise ArgumentError, "Invalid repository paths"
      end
    end

    def mapping_reason(job)
      mapping = job["mapping"]
      unless mapping.is_a?(Hash) && [2, 3].include?(mapping["version"]) &&
               mapping["complete"] == true && mapping["revision"].is_a?(String) &&
               mapping["revision"].match?(/\A[0-9a-f]{40}\z/) &&
               mapping["environment"] == job.fetch("environment") && mapping["tests"].is_a?(Hash) &&
               mapping["initialization_sources"].is_a?(Array) &&
               (
                 if mapping["version"] == 3
                   mapping["dependency_graph"].is_a?(Hash) &&
                     mapping["dependency_graph"]["version"] == 1
                 else
                   mapping["source_dependencies"].is_a?(Hash)
                 end
               )
        return "Missing or incompatible mapping"
      end
      validate_paths!(mapping.fetch("sources"))
      validate_paths!(mapping.fetch("initialization_sources"))
      validate_paths!(mapping.fetch("shared_files"))
      validate_paths!(mapping.fetch("tests").keys)
      if mapping.fetch("version") == 3
        validate_paths!(mapping.fetch("dependency_graph")["paths"])
      else
        mapping.fetch("tests").each_value { |dependencies| validate_paths!(dependencies) }
        mapping
          .fetch("source_dependencies")
          .each do |source, dependencies|
            validate_paths!([source])
            validate_paths!(dependencies)
          end
      end
      added = job.fetch("inventory") - mapping.fetch("tests").keys
      removed = mapping.fetch("tests").keys - job.fetch("inventory")
      explained = @test_changes + job.fetch("mapping_changes")
      unless (added - explained).empty? &&
               (removed - @deleted_tests - job.fetch("mapping_changes")).empty?
        return "Unexplained test inventory change"
      end
      nil
    end

    def select_dependencies(name:, job:, reasons:)
      reason = mapping_reason(job)
      if !reason && job.fetch("mapping_shared_test_changes", []).any?
        reason =
          "Shared test setup changed since mapping: #{job.fetch("mapping_shared_test_changes").join(", ")}"
      end
      mapping = job["mapping"]
      mapped_tests =
        mapping.is_a?(Hash) && mapping["tests"].is_a?(Hash) ? mapping.fetch("tests").keys : []
      test_inputs = @test_changes + job.fetch("inventory") + mapped_tests
      changes = (@changes + job.fetch("mapping_changes")).uniq - test_inputs
      protected_initialization =
        job
          .fetch("verified_sources")
          .select do |path|
            mapping.is_a?(Hash) && mapping["source_checks"].is_a?(Hash) &&
              mapping.fetch("source_checks")[path].is_a?(Hash)
          end
      if !reason
        changes.each do |path|
          if mapping.fetch("shared_files").include?(path)
            reason = "Shared input: #{path}"
            break
          end
          next if documentation?(path)
          if mapping.fetch("initialization_sources").include?(path) &&
               !protected_initialization.include?(path)
            reason = "Initialization input: #{path}"
          elsif !mapping.fetch("sources").include?(path)
            reason = "Unknown input: #{path}"
          elsif !job.fetch("verified_sources").include?(path)
            reason = "Unverified source structure: #{path}"
          end
          break if reason
        end
      end
      if reason
        job.fetch("inventory").each { |file| reasons[file] << "#{name}: #{reason}" }
        return
      end
      (job.fetch("inventory") & job.fetch("mapping_changes")).each do |file|
        reasons[file] << "Test changed since mapping: #{file}"
      end
      graph = dependency_graph(mapping)
      affected = (changes + job.fetch("changed_methods", [])).to_set
      affected.merge(graph.affected_sources(affected.to_a))
      initialization =
        (affected & (mapping.fetch("initialization_sources") - protected_initialization).to_set)
          .to_a
          .sort
          .first
      if initialization
        job
          .fetch("inventory")
          .each { |file| reasons[file] << "#{name}: Initialization input: #{initialization}" }
        return
      end
      inventory = job.fetch("inventory").to_set
      graph
        .affected_tests(affected)
        .each do |file, dependencies|
          next unless inventory.include?(file)
          dependencies.each { |source| reasons[file] << "Dependency: #{source}" }
        end
    end

    def dependency_graph(mapping)
      if mapping.fetch("version") == 3
        DependencyGraph.new(
          serialized: mapping.fetch("dependency_graph"),
          tests: mapping.fetch("tests"),
        )
      else
        graph = DependencyGraph.new
        mapping
          .fetch("source_dependencies")
          .each { |source, dependencies| graph.record(source: source, dependencies: dependencies) }
        mapping
          .fetch("tests")
          .each { |file, dependencies| graph.record_test(file: file, dependencies: dependencies) }
        graph
      end
    end
  end

  def self.write_plan(input:, output:)
    if File.expand_path(input) == File.expand_path(output) ||
         (File.exist?(input) && File.exist?(output) && File.identical?(input, output))
      raise ArgumentError, "Plan input and output must be different files"
    end
    FileUtils.rm_f(output)
    pending = "#{output}.pending-#{Process.pid}"
    begin
      plan = Planner.new(JSON.parse(File.read(input))).plan
      File.write(pending, JSON.generate(plan))
      File.rename(pending, output)
    ensure
      FileUtils.rm_f(pending)
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    unless ARGV.length == 3 && ARGV.first == "plan"
      raise ArgumentError, "Expected plan INPUT OUTPUT"
    end
    TestSelection.write_plan(input: ARGV[1], output: ARGV[2])
  rescue StandardError => error
    warn error.message
    exit 1
  end
end
