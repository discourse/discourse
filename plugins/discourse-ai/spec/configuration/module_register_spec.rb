# frozen_string_literal: true

describe DiscourseAi::Configuration::Module do
  after { described_class.registered_modules.clear }

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
      2.times do
        described_class.register(
          "test_module",
          module_id: 200,
          module_name: "test_module",
          features: [],
        )
      end

      expect(described_class.registered_modules.size).to eq(1)
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

    it "resolves callable features" do
      feature =
        DiscourseAi::Configuration::Feature.new(
          "test_feature",
          nil,
          200,
          "test_module",
          agent_ids_lookup: -> { [-999] },
        )

      described_class.register(
        "test_module",
        module_id: 200,
        module_name: "test_module",
        features: -> { [feature] },
      )

      all_modules = described_class.all
      test_mod = all_modules.find { |m| m.name == "test_module" }
      expect(test_mod.features.size).to eq(1)
      expect(test_mod.features.first.name).to eq("test_feature")
    end
  end
end
