# frozen_string_literal: true
require "json"
require_relative "rspec_source_structure"
require_relative "dependency_graph"

module TestMapping
  def self.merge(catalog:, job_name:, directory:, execution_directory:, output:)
    job = catalog.fetch("jobs").fetch(job_name)
    inventory = job.fetch("inventory")
    tests = inventory.to_h { |path| [path, true] }
    graph = TestSelection::DependencyGraph.new
    inventory.each { |file| graph.record_test(file: file, dependencies: []) }
    boot_lines = Hash.new { |hash, path| hash[path] = [] }
    observed_sources = Set.new
    initialization_sources = Set.new
    uncertain_sources = Set.new
    shared_files = Set.new
    file_metadata = Hash.new { |hash, path| hash[path] = [] }
    records =
      Dir["#{execution_directory}/rspec-*.json"].map do |path|
        record = JSON.parse(File.read(path))
        part = JSON.parse(File.read("#{directory}/worker-#{File.basename(path)[/\d+/]}.json"))
        unless part.fetch("version") == 5 &&
                 record.fetch("revision") == catalog.fetch("revision") &&
                 part.fetch("revision") == catalog.fetch("revision") && part.fetch("complete") &&
                 part.fetch("files").sort == record.fetch("files").sort &&
                 part.fetch("identity") == record.fetch("identity") &&
                 part.fetch("pid") == record.fetch("pid") &&
                 part.fetch("environment") == job.fetch("environment")
          raise "Incomplete or incompatible worker mapping"
        end
        part
          .fetch("dependencies")
          .each do |file, dependencies|
            tests.fetch(file)
            graph.record_test(file: file, dependencies: dependencies)
          end
        part.fetch("tests").each_key { |file| tests.fetch(file) }
        graph.merge(serialized: part.fetch("dependency_graph"), tests: part.fetch("tests"))
        part.fetch("boot_lines").each { |source, lines| boot_lines[source] |= lines }
        part.fetch("initialization_lines", {}).each { |source, lines| boot_lines[source] |= lines }
        observed_sources.merge(part.fetch("observed_sources", []))
        initialization_sources.merge(part.fetch("initialization_sources"))
        uncertain_sources.merge(part.fetch("uncertain_sources", []))
        shared_files.merge(part.fetch("shared_files"))
        part
          .fetch("file_metadata", {})
          .each { |source, descriptions| file_metadata[source] |= descriptions }
        record
      end
    if job.fetch("command").first == "bin/turbo_rspec" && inventory.any?
      manifest = JSON.parse(File.read("#{execution_directory}/execution-manifest.json"))
      unless manifest.fetch("revision") == catalog.fetch("revision") &&
               manifest
                 .fetch("workers")
                 .all? { |identity, assigned|
                   records.any? do |record|
                     record.fetch("identity") == identity &&
                       record.fetch("pid") == assigned.fetch("pid") &&
                       record.fetch("files").sort == assigned.fetch("files").sort
                   end
                 }
        raise "Mapping execution is missing a required role"
      end
    end
    unless records.flat_map { |record| record.fetch("files") }.uniq.sort == inventory.sort
      raise "Mapping execution does not cover the job inventory"
    end
    sources = (graph.paths + observed_sources.to_a).uniq.select { |path| File.file?(path) }
    checks =
      sources
        .grep(/\.rb\z/)
        .to_h { |path| [path, RspecSourceStructure.describe(path, boot_lines: boot_lines[path])] }
    uncertain_sources.each { |path| checks[path] = nil if checks.key?(path) }
    mapping = {
      "version" => 3,
      "revision" => catalog.fetch("revision"),
      "complete" => true,
      "environment" => job.fetch("environment"),
      "tests" => graph.encoded_tests,
      "sources" => sources.sort,
      "dependency_graph" => graph.to_h,
      "source_checks" => checks,
      "initialization_sources" => initialization_sources.to_a.sort,
      "shared_files" => shared_files.to_a.sort,
      "file_metadata" => file_metadata.to_h,
    }
    File.write(output, JSON.generate(mapping))
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    raise ArgumentError, "Expected CATALOG JOB MAPPINGS EXECUTIONS OUTPUT" unless ARGV.length == 5
    TestMapping.merge(
      catalog: JSON.parse(File.read(ARGV[0])),
      job_name: ARGV[1],
      directory: ARGV[2],
      execution_directory: ARGV[3],
      output: ARGV[4],
    )
  rescue StandardError => error
    warn error.message
    exit 1
  end
end
