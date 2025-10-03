# frozen_string_literal: true

RSpec.describe "Summarize a channel since your last visit", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:group)
  fab!(:channel) { Fabricate(:chat_channel) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel) }
  let(:chat) { PageObjects::Pages::Chat.new }
  let(:summarization_result) { "This is a summary" }

  before do
    enable_current_plugin

    group.add(current_user)

    assign_fake_provider_to(:ai_default_llm_model)
    assign_persona_to(:ai_summarization_persona, [group.id])
    SiteSetting.ai_summarization_enabled = true

    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = group.id.to_s
    sign_in(current_user)
    chat_system_bootstrap(current_user, [channel])
  end

  it "displays a summary of the messages since the selected timeframe" do
    DiscourseAi::Completions::Llm.with_prepared_responses([summarization_result]) do
      chat.visit_channel(channel)

      find(".chat-composer-dropdown__trigger-btn").click
      find(".chat-composer-dropdown__action-btn.channel-summary").click

      expect(page.has_css?(".chat-modal-channel-summary")).to eq(true)

      find(".summarization-since").click
      find(".select-kit-row[data-value=\"3\"]").click

      expect(find(".summary-area").text).to eq(summarization_result)
    end
  end
end
