# frozen_string_literal: true

describe DiscourseAi::Configuration::Feature do
  fab!(:fake_plugin) do
    plugin = Plugin::Instance.new
    plugin.path = "#{Rails.root.join("spec/fixtures/plugins/my_plugin/plugin.rb")}"
    plugin
  end

  before do
    DiscourseAi.register_feature(
      module_name: :test_plugin,
      feature: :test_feature,
      agent_klass: DiscourseAi::TestHelpers::FakeExternalAgent,
      plugin: fake_plugin,
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
