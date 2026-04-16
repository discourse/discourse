# frozen_string_literal: true

unless defined?(FakeExternalAgent)
  class FakeExternalAgent < DiscourseAi::Agents::Agent
    def tools
      []
    end

    def system_prompt
      "Test agent"
    end
  end
end

describe DiscourseAi::Configuration::Feature do
  fab!(:fake_plugin) do
    plugin = Plugin::Instance.new
    plugin.path = "#{Rails.root}/spec/fixtures/plugins/my_plugin/plugin.rb"
    plugin
  end

  before do
    DiscoursePluginRegistry.register_external_ai_feature(
      {
        module_name: :test_plugin,
        feature: :test_feature,
        agent_klass: FakeExternalAgent,
        enabled_by_setting: nil,
      },
      fake_plugin,
    )
  end

  after do
    DiscoursePluginRegistry._raw_external_ai_features.reject! do |entry|
      entry[:value][:module_name] == :test_plugin
    end
  end

  describe ".all with filtered registry" do
    it "includes features from the external AI features registry" do
      all_features = described_class.all
      test_feature = all_features.find { |f| f.name == "test_feature" }
      expect(test_feature).to be_present
    end

    it "assigns the correct agent setting name" do
      all_features = described_class.all
      test_feature = all_features.find { |f| f.name == "test_feature" }
      expect(test_feature.agent_setting).to eq("test_plugin_test_feature_agent")
    end
  end
end
