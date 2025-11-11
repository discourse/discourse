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
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_bot_enabled = true
  end

  describe "#ai_search_discoveries" do
    before do
      SiteSetting.ai_discover_persona = ai_persona.id
      group.add(user)
    end

    it "is present" do
      expect(described_class.new.ai_search_discoveries).to eq(true)
    end
  end
end
