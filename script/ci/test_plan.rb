# frozen_string_literal: true
require "json"
require "open3"
require_relative "test_selection"
require_relative "rspec_source_structure"
require_relative "test_inventory"

module TestPlan
  def self.git(*arguments)
    output, status = Open3.capture2("git", *arguments)
    raise "Cannot inspect changeset" unless status.success?
    output
  end
  private_class_method :git

  def self.prepare(catalog_path:, mapping_directory:, base:, revision:, output:, mode:, main:)
    destinations = [output, "#{output}.input.json", "#{output}.reference.json"]
    if destinations.any? { |path| File.expand_path(path) == File.expand_path(catalog_path) }
      raise ArgumentError, "Plan output overlaps its catalog"
    end
    destinations.each { |path| FileUtils.rm_f(path) }
    unless [base, revision].all? { |value| value.is_a?(String) && value.match?(/\A[0-9a-f]{40}\z/) }
      raise ArgumentError, "Invalid changeset revisions"
    end
    catalog = JSON.parse(File.read(catalog_path))
    raise "Catalog revision mismatch" unless catalog.fetch("revision") == revision
    changes = git("diff", "--no-renames", "--name-only", "-z", "#{base}...#{revision}").split("\0")
    deleted =
      git(
        "diff",
        "--no-renames",
        "--name-only",
        "--diff-filter=D",
        "-z",
        "#{base}...#{revision}",
      ).split("\0")
    inventories = catalog.fetch("jobs").values.flat_map { |job| job.fetch("inventory") }.uniq
    test_changes =
      changes.select { |path| inventories.include?(path) || TestInventory.test_file?(path) }
    jobs =
      catalog
        .fetch("jobs")
        .to_h do |name, job|
          mapping_path = File.join(mapping_directory, "#{name}.json")
          mapping = nil
          if !main && mode != "full" && File.file?(mapping_path)
            begin
              mapping = JSON.parse(File.read(mapping_path))
            rescue JSON::ParserError
              mapping = nil
            end
          end
          drift = []
          verified = []
          changed_methods = []
          if mapping && !main && mode != "full"
            begin
              raise "Invalid mapping" unless mapping.is_a?(Hash)
              producer = mapping["revision"]
              unless producer.is_a?(String) && producer.match?(/\A[0-9a-f]{40}\z/)
                raise "Invalid producer revision"
              end
              raise "Invalid source checks" unless mapping.fetch("source_checks", {}).is_a?(Hash)
              ancestor = git("merge-base", producer, base).strip
              drift =
                git(
                  "log",
                  "--no-renames",
                  "--format=",
                  "--name-only",
                  "-z",
                  "#{ancestor}..#{producer}",
                  "#{ancestor}..#{base}",
                ).split("\0").map(&:strip).reject(&:empty?).uniq
              relevant = (changes + drift).uniq
              verified =
                mapping
                  .fetch("source_checks", {})
                  .filter_map do |path, description|
                    if relevant.include?(path) &&
                         RspecSourceStructure.matches?(path: path, description: description)
                      path
                    end
                  end
              changed_methods =
                verified.flat_map do |path|
                  RspecSourceStructure.changed_methods(
                    path: path,
                    description: mapping.fetch("source_checks").fetch(path),
                  )
                end
            rescue RuntimeError
              mapping = nil
            end
          end
          [
            name,
            job.merge(
              "mapping" => mapping,
              "mapping_changes" => drift,
              "verified_sources" => verified,
              "changed_methods" => changed_methods,
            ),
          ]
        end
    input = {
      "revision" => revision,
      "mode" => mode,
      "main" => main,
      "changes" => changes,
      "test_changes" => test_changes,
      "deleted_tests" => deleted & test_changes,
      "jobs" => jobs,
    }
    input["global_inventory"] = catalog.fetch("global_inventory") if catalog.key?(
      "global_inventory",
    )
    File.write("#{output}.input.json", JSON.pretty_generate(input))
    TestSelection.write_plan(input: "#{output}.input.json", output: output)
    if mode == "audit" && !main
      reference = TestSelection::Planner.new(input.merge("mode" => "full")).plan
      File.write("#{output}.reference.json", JSON.pretty_generate(reference))
    end
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    raise ArgumentError, "Expected CATALOG MAPPINGS BASE REVISION OUTPUT" unless ARGV.length == 5
    TestPlan.prepare(
      catalog_path: ARGV[0],
      mapping_directory: ARGV[1],
      base: ARGV[2],
      revision: ARGV[3],
      output: ARGV[4],
      mode: ENV.fetch("TEST_SELECTION_MODE", "audit"),
      main: ENV["GITHUB_REF"] == "refs/heads/main",
    )
  rescue StandardError => error
    warn error.message
    exit 1
  end
end
