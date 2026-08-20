# frozen_string_literal: true

describe UserOption do
  fab!(:user)
  fab!(:llm_model)
  fab!(:group)
  fab!(:ai_agent) do
    Fabricate(:ai_agent, allowed_group_ids: [group.id], default_llm_id: llm_model.id)
  end

  before do
    enable_current_plugin
    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_bot_enabled = true
  end

  describe "#ai_search_discoveries" do
    before do
      SiteSetting.ai_discover_agent = ai_agent.id
      group.add(user)
    end

    it "is present" do
      expect(described_class.new.ai_search_discoveries).to eq(true)
    end

    it "has sensible result preference defaults" do
      option = described_class.new

      expect(option).to have_attributes(
        ai_search_discoveries_mode: 1,
        ai_search_discoveries_show_summary: true,
        ai_search_discoveries_summary_detail: 1,
        ai_search_discoveries_related_count: 2,
      )
    end

    it "accepts every supported result preference" do
      expect(
        described_class.new(
          ai_search_discoveries_mode: 0,
          ai_search_discoveries_summary_detail: 2,
          ai_search_discoveries_related_count: 6,
        ),
      ).to be_valid
    end

    it "rejects unsupported result preferences" do
      option =
        described_class.new(
          ai_search_discoveries_mode: 3,
          ai_search_discoveries_summary_detail: -1,
          ai_search_discoveries_related_count: 7,
        )

      expect(option).not_to be_valid
      expect(option.errors).to include(
        :ai_search_discoveries_mode,
        :ai_search_discoveries_summary_detail,
        :ai_search_discoveries_related_count,
      )

      option.ai_search_discoveries_related_count = nil
      expect(option).not_to be_valid
      expect(option.errors).to include(:ai_search_discoveries_related_count)
    end
  end
end
