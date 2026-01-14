#frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::ListTags do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    SiteSetting.tagging_enabled = true
  end

  describe "#process" do
    it "can generate correct info" do
      Fabricate(:tag, name: "america", public_topic_count: 100)
      Fabricate(:tag, name: "not_here", public_topic_count: 0)

      info = described_class.new({}, bot_user: bot_user, llm: llm).invoke

      expect(info.to_s).to include("america")
      expect(info.to_s).not_to include("not_here")
    end
  end
end
