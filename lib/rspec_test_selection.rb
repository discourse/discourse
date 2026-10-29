# frozen_string_literal: true

require "json"
require "open3"
require "fileutils"

module RspecTestSelection
  def self.plan(root:, baseline:)
    specs = inventory(root)
    return full(specs, "No baseline") unless baseline
    unless baseline["version"] == 1 && baseline["suite"] == "core-backend"
      return full(specs, "Incompatible baseline")
    end

    revision = baseline.fetch("revision")
    raise "Invalid baseline revision" unless revision.match?(/\A[0-9a-f]{40}\z/)
    output, status =
      Open3.capture2e(
        "git",
        "-C",
        root,
        "diff",
        "--name-only",
        "--no-renames",
        "-z",
        revision,
        "HEAD",
        "--",
      )
    raise output unless status.success?
    changed = output.split("\0")
    supported =
      changed.all? { |path| path.match?(%r{\A(?:app|lib)/.+\.rb\z}) || specs.include?(path) }
    return full(specs, "Shared or untraceable input changed") unless supported

    entries = baseline.fetch("specs")
    mapped = entries.values.flat_map { |entry| entry.fetch("inputs") }
    sources = changed.select { |path| path.start_with?("app/", "lib/") }
    return full(specs, "Unmapped source") if (sources - mapped).any?

    selected =
      specs.select do |spec|
        entry = entries[spec]
        !entry || !entry.fetch("passed") || changed.include?(spec) ||
          (entry.fetch("inputs") & changed).any?
      end
    return full(specs, "Empty selection") if selected.empty?
    {
      "mode" => "subset",
      "reason" => "Recorded runtime dependencies and mapping drift",
      "specs" => selected,
      "total_specs" => specs.size,
      "baseline_revision" => revision,
    }
  rescue StandardError => error
    full(specs || inventory(root), "Invalid baseline: #{error.class}")
  end

  def self.merge(root:, records:)
    entries = {}
    records.each do |record|
      record
        .fetch("specs")
        .each do |spec, entry|
          current = entries[spec] ||= { "passed" => true, "inputs" => [] }
          current["passed"] &&= entry.fetch("passed")
          current["inputs"] |= entry.fetch("inputs")
        end
    end
    raise "No recorded specs" if entries.empty?
    {
      "version" => 1,
      "suite" => "core-backend",
      "revision" => Open3.capture2("git", "-C", root, "rev-parse", "HEAD").first.strip,
      "specs" => entries.sort.to_h,
    }
  end

  def self.inventory(root)
    Dir
      .glob("spec/**/*_spec.rb", base: root)
      .reject { |path| path.start_with?("spec/system/") }
      .sort
  end

  def self.full(specs, reason)
    { "mode" => "full", "reason" => reason, "specs" => specs, "total_specs" => specs.size }
  end
  private_class_method :full
end
