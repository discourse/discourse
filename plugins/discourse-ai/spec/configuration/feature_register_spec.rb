# frozen_string_literal: true

describe DiscourseAi::Configuration::Feature do
  after { DiscourseAi::Configuration::Module.registered_modules.clear }

  describe ".all with registered modules" do
    it "includes features from registered modules" do
      feature =
        described_class.new(
          "test_feature",
          nil,
          200,
          "test_module",
          agent_ids_lookup: -> { [-999] },
        )

      DiscourseAi::Configuration::Module.register(
        "test_module",
        module_id: 200,
        module_name: "test_module",
        features: [feature],
      )

      all_features = described_class.all
      expect(all_features).to include(feature)
    end

    it "finds registered features by agent_id" do
      feature =
        described_class.new(
          "test_feature",
          nil,
          200,
          "test_module",
          agent_ids_lookup: -> { [-501] },
        )

      DiscourseAi::Configuration::Module.register(
        "test_module",
        module_id: 200,
        module_name: "test_module",
        features: [feature],
      )

      found = described_class.find_features_using(agent_id: -501)
      expect(found).to include(feature)
    end
  end
end
