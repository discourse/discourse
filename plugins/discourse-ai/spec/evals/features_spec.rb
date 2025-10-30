# frozen_string_literal: true

require_relative "../../evals/lib/features"
require_relative "../../lib/configuration/module"
require_relative "../../lib/configuration/feature"

RSpec.describe DiscourseAi::Evals::Features do
  subject(:features) { described_class.new(modules: modules, output: output) }

  let(:modules) do
    [
      DiscourseAi::Configuration::Module.new(
        1,
        "module-1",
        enabled_by_setting: "setting-1",
        features: [
          DiscourseAi::Configuration::Feature.new("feature-1", "persona-1", 1, "module-1"),
        ],
      ),
      DiscourseAi::Configuration::Module.new(
        2,
        "module-2",
        enabled_by_setting: "setting-2",
        features: [
          DiscourseAi::Configuration::Feature.new("feature-2", "persona-2", 2, "module-2"),
        ],
      ),
    ]
  end

  let(:output) { StringIO.new }

  describe "#feature_keys" do
    it "matches the features exposed by the configuration modules" do
      expected_keys =
        modules.flat_map { |mod| mod.features.map { |feature| "#{mod.name}:#{feature.name}" } }

      expect(features.feature_keys).to match_array(expected_keys)
    end
  end

  describe "#valid_feature_key?" do
    let(:known_module) { modules.first }
    let(:known_feature) { known_module.features.first }
    let(:known_key) { "#{known_module.name}:#{known_feature.name}" }

    it "returns true when the key matches a registered feature" do
      expect(features.valid_feature_key?(known_key)).to be(true)
    end

    it "returns false for unknown features" do
      expect(features.valid_feature_key?("search:unknown")).to be(false)
    end
  end

  describe "#feature_map" do
    let(:evals) do
      [
        Struct.new(:id, :feature).new("eval-3", "module-1:feature-1"),
        Struct.new(:id, :feature).new("eval-1", "module-1:feature-1"),
        Struct.new(:id, :feature).new("eval-2", "module-2:feature-2"),
      ]
    end

    it "groups evaluations by feature and sorts their ids" do
      expect(features.feature_map(evals)).to eq(
        "module-1:feature-1" => %w[eval-1 eval-3],
        "module-2:feature-2" => %w[eval-2],
      )
    end

    it "returns an empty hash when no evaluations are registered" do
      empty_features = described_class.new(modules: modules, output: output)

      expect(empty_features.feature_map([])).to eq({})
    end
  end

  describe "#print" do
    it "prints the configured modules and their features" do
      features.print

      expect(output.string).to include("module-2\n")
      expect(output.string).to include("  - module-2:feature-2\n")
    end

    it "prints a placeholder for modules without features" do
      empty_module =
        DiscourseAi::Configuration::Module.new(999, "custom", features: [], enabled_by_setting: nil)
      modules_with_empty = modules + [empty_module]
      custom_features = described_class.new(modules: modules_with_empty, output: output)

      custom_features.print

      expect(output.string).to include("custom\n  - no registered features\n")
    end
  end
end
