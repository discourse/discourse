# frozen_string_literal: true

describe DiscourseAi::Configuration::Module do
  after { described_class.registered_modules.delete("test_module") }

  describe ".register" do
    it "adds a module to registered_modules" do
      described_class.register(
        "test_module",
        module_id: 200,
        module_name: "test_module",
        features: [],
        enabled_by_setting: "some_setting",
      )

      expect(described_class.registered_modules).to have_key("test_module")
      expect(described_class.registered_modules["test_module"][:module_id]).to eq(200)
    end

    it "deduplicates by key on re-registration" do
      initial_size = described_class.registered_modules.size

      2.times do
        described_class.register(
          "test_module",
          module_id: 200,
          module_name: "test_module",
          features: [],
        )
      end

      expect(described_class.registered_modules.size).to eq(initial_size + 1)
    end

    it "includes registered modules in .all" do
      described_class.register(
        "test_module",
        module_id: 200,
        module_name: "test_module",
        features: [],
        enabled_by_setting: "data_explorer_enabled",
      )

      all_modules = described_class.all
      test_mod = all_modules.find { |m| m.name == "test_module" }
      expect(test_mod).to be_present
      expect(test_mod.id).to eq(200)
    end

    it "merges features when registered multiple times" do
      feature1 =
        DiscourseAi::Configuration::Feature.new(
          "feature_one",
          nil,
          200,
          "test_module",
          agent_ids_lookup: -> { [-999] },
        )
      feature2 =
        DiscourseAi::Configuration::Feature.new(
          "feature_two",
          nil,
          200,
          "test_module",
          agent_ids_lookup: -> { [-998] },
        )

      described_class.register(
        "test_module",
        module_id: 200,
        module_name: "test_module",
        features: [feature1],
      )
      described_class.register(
        "test_module",
        module_id: 200,
        module_name: "test_module",
        features: [feature2],
      )

      all_modules = described_class.all
      test_mod = all_modules.find { |m| m.name == "test_module" }
      expect(test_mod.features.map(&:name)).to contain_exactly("feature_one", "feature_two")
    end
  end
end
