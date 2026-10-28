# frozen_string_literal: true

RSpec.describe DiscourseAi::BotUser do
  before do
    enable_current_plugin
    PluginStore.remove(described_class::STORE_NAMESPACE, described_class::FLOOR_KEY)
  end

  describe ".next_id" do
    it "uses the same helper and persisted floor as core allocation" do
      PluginStore.set(DiscourseAi::PLUGIN_NAME, described_class::FLOOR_KEY, -5000)

      expect(described_class).to equal(::BotUser)
      expect([::BotUser.next_id, described_class.next_id, ::BotUser.next_id]).to eq(
        [-5001, -5002, -5003],
      )
      expect(described_class.floor).to eq(-5003)
    end

    it "reserves dangling agent references before either creation path allocates" do
      agent = Fabricate(:ai_agent)
      agent.update_columns(user_id: -6000)

      expect(::BotUser.next_id).to eq(-6001)
      expect(described_class.next_id).to eq(-6002)
    end

    it "reserves dangling model references even when the plugin is disabled" do
      model = Fabricate(:llm_model)
      model.update_columns(user_id: -9000)
      SiteSetting.discourse_ai_enabled = false

      expect(::BotUser.next_id).to eq(-9001)
      expect(described_class.next_id).to eq(-9002)
    end
  end
end
