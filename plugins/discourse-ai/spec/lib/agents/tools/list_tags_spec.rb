#frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::ListTags do
  fab!(:llm_model)
  fab!(:bot_user, :admin)
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

    it "does not leak hidden staff-only tag names" do
      Fabricate(:tag, name: "america", public_topic_count: 100)
      hidden_tag = Fabricate(:tag, name: "secret_staff_tag", public_topic_count: 50)
      Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])

      info = described_class.new({}, bot_user: bot_user, llm: llm).invoke

      expect(info.to_s).to include("america")
      expect(info.to_s).not_to include("secret_staff_tag")
    end
  end
end
