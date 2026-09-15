# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::ListCategories do
  fab!(:llm_model)
  fab!(:bot_user, :admin)
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  describe "#process" do
    it "list available categories" do
      Fabricate(:category, name: "america", posts_year: 999)

      info = described_class.new({}, bot_user: bot_user, llm: llm).invoke.to_s

      expect(info).to include("america")
      expect(info).to include("999")
    end
  end
end
