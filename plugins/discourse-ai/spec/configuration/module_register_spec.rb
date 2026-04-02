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

describe DiscourseAi::Configuration::Module do
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
    it "includes modules registered via the external AI features registry" do
      all_modules = described_class.all
      test_mod = all_modules.find { |m| m.name == :test_plugin }
      expect(test_mod).to be_present
      expect(test_mod.features.map(&:name)).to include("test_feature")
    end

    it "assigns a stable module ID from the module name" do
      all_modules = described_class.all
      test_mod = all_modules.find { |m| m.name == :test_plugin }
      expected_id = described_class.external_module_id(:test_plugin)
      expect(test_mod.id).to eq(expected_id)
    end

    context "with multiple features gated by different settings" do
      before do
        DiscoursePluginRegistry._raw_external_ai_features.reject! do |entry|
          entry[:value][:module_name] == :test_plugin
        end

        DiscoursePluginRegistry.register_external_ai_feature(
          {
            module_name: :test_plugin,
            feature: :feature_a,
            agent_klass: FakeExternalAgent,
            enabled_by_setting: "data_explorer_enabled",
          },
          fake_plugin,
        )

        DiscoursePluginRegistry.register_external_ai_feature(
          {
            module_name: :test_plugin,
            feature: :feature_b,
            agent_klass: FakeExternalAgent,
            enabled_by_setting: "data_explorer_ai_queries_enabled",
          },
          fake_plugin,
        )
      end

      it "is enabled when at least one feature is enabled" do
        SiteSetting.data_explorer_enabled = true
        SiteSetting.data_explorer_ai_queries_enabled = false

        test_mod = described_class.all.find { |m| m.name == :test_plugin }
        expect(test_mod).to be_enabled
      end

      it "is disabled when all features are disabled" do
        SiteSetting.data_explorer_enabled = false
        SiteSetting.data_explorer_ai_queries_enabled = false

        test_mod = described_class.all.find { |m| m.name == :test_plugin }
        expect(test_mod).not_to be_enabled
      end
    end
  end
end
