# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiFeaturesController do
  let(:controller) { described_class.new }
  fab!(:admin)
  fab!(:group)
  fab!(:llm_model)
  fab!(:summarizer_persona) { Fabricate(:ai_persona) }
  fab!(:alternate_summarizer_persona) { Fabricate(:ai_persona) }

  before do
    enable_current_plugin
    sign_in(admin)
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_bot_enabled = true
  end

  describe "#index" do
    it "lists all features backed by personas" do
      get "/admin/plugins/discourse-ai/ai-features.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["ai_features"].count).to eq(9)
    end

    it "includes automation-related features" do
      SiteSetting.discourse_automation_enabled = true

      get "/admin/plugins/discourse-ai/ai-features.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["ai_features"].count).to eq(11)
    end
  end

  describe "#edit" do
    it "returns a success response" do
      get "/admin/plugins/discourse-ai/ai-features/1/edit.json"
      expect(response.parsed_body["module_name"]).to eq("summarization")
    end
  end
end
