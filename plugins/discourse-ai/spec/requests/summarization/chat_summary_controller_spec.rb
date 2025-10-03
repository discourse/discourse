# frozen_string_literal: true

RSpec.describe DiscourseAi::Summarization::ChatSummaryController do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:group)

  before do
    enable_current_plugin

    group.add(current_user)

    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_summarization_enabled = true
    SiteSetting.ai_custom_summarization_allowed_groups = group.id

    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = group.id
    sign_in(current_user)
  end

  describe "#show" do
    context "when the user is not allowed to join the channel" do
      fab!(:channel) { Fabricate(:private_category_channel) }

      it "returns a 403" do
        get "/discourse-ai/summarization/channels/#{channel.id}", params: { since: 6 }

        expect(response.status).to eq(403)
      end
    end
  end
end
