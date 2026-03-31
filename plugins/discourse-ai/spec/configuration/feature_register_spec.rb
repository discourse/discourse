# frozen_string_literal: true

describe DiscourseAi::Configuration::Feature do
  before { SiteSetting.data_explorer_enabled = true }

  describe ".all with filtered registry" do
    it "includes features from registered external AI features" do
      all_features = described_class.all
      de_feature = all_features.find { |f| f.name == "query_generation" }

      expect(de_feature).to be_present
    end

    it "finds registered features by agent_id" do
      agent_id =
        DiscourseAi::Agents::Agent::RESERVED_EXTERNAL_IDS.dig(
          :data_explorer,
          :features,
          :query_generation,
          :agent_id,
        )
      found = described_class.find_features_using(agent_id: agent_id)
      expect(found.map(&:name)).to include("query_generation")
    end
  end
end
