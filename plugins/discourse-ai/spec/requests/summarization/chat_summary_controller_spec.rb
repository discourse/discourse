# frozen_string_literal: true

RSpec.describe DiscourseAi::Summarization::ChatSummaryController do
  fab!(:current_user, :user)
  fab!(:group)

  before do
    enable_current_plugin

    group.add(current_user)

    assign_fake_provider_to(:ai_default_llm_model)
    SiteSetting.ai_summarization_enabled = true

    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = group.id
    sign_in(current_user)
  end

  describe "#show" do
    context "when the user can join the channel" do
      fab!(:channel, :category_channel)
      fab!(:message) { Fabricate(:chat_message, chat_channel: channel) }

      before { assign_agent_to(:ai_summarization_agent, [group.id]) }

      it "returns a summary" do
        summary = "This is a summary"

        DiscourseAi::Completions::Llm.with_prepared_responses([summary]) do
          post "/discourse-ai/summarization/channels/#{channel.id}.json", params: { since: 6 }

          expect(response.status).to eq(200)
          expect(response.parsed_body["summary"]).to eq(summary)
        end
      end
    end

    context "when the user is not allowed to join the channel" do
      fab!(:channel, :private_category_channel)

      it "returns a 403" do
        post "/discourse-ai/summarization/channels/#{channel.id}", params: { since: 6 }

        expect(response.status).to eq(403)
      end
    end
  end
end
