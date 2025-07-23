# frozen_string_literal: true

RSpec.describe UserOption do
  fab!(:user)
  fab!(:llm_model)
  fab!(:group)
  fab!(:ai_persona) do
    Fabricate(:ai_persona, allowed_group_ids: [group.id], default_llm_id: llm_model.id)
  end

  before do
    enable_current_plugin

    assign_fake_provider_to(:ai_helper_model)
    assign_fake_provider_to(:ai_helper_image_caption_model)
    SiteSetting.ai_helper_enabled = true
    SiteSetting.ai_helper_enabled_features = "image_caption"
    SiteSetting.ai_auto_image_caption_allowed_groups = "10" # tl0

    SiteSetting.ai_bot_enabled = true
  end

  describe "#auto_image_caption" do
    it "is present" do
      expect(described_class.new.auto_image_caption).to eq(false)
    end
  end

  describe "#ai_search_discoveries" do
    before do
      SiteSetting.ai_bot_discover_persona = ai_persona.id
      group.add(user)
    end

    it "is present" do
      expect(described_class.new.ai_search_discoveries).to eq(true)
    end
  end
end
