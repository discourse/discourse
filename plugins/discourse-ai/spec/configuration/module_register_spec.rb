# frozen_string_literal: true

describe DiscourseAi::Configuration::Module do
  fab!(:fake_plugin) do
    plugin = Plugin::Instance.new
    plugin.path = "#{Rails.root}/spec/fixtures/plugins/my_plugin/plugin.rb"
    plugin
  end

  let(:fake_agent_class) do
    Class.new(DiscourseAi::Agents::Agent) do
      def tools
        []
      end

      def temperature
        0.2
      end

      def system_prompt
        "You are a test agent."
      end
    end
  end

  before do
    DiscoursePluginRegistry.register_external_ai_feature(
      {
        module_name: :test_plugin,
        feature: :test_feature,
        klass: fake_agent_class,
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
  end
end
