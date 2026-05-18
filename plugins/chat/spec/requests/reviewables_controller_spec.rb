# frozen_string_literal: true

RSpec.describe ReviewablesController do
  fab!(:moderator)
  fab!(:message_author) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:flagger) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:direct_message_channel) do
    Fabricate(:direct_message_channel, users: [message_author, flagger])
  end

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.chat_message_flag_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  describe "#index" do
    it "does not expose unrelated direct-message last message content to moderators" do
      flagged_message_text = "flagged direct message content"
      unrelated_last_message_text = "unrelated later direct message secret"
      flagged_message =
        Fabricate(
          :chat_message,
          chat_channel: direct_message_channel,
          user: message_author,
          message: flagged_message_text,
        )

      result =
        Chat::ReviewQueue.new.flag_message(
          flagged_message,
          Guardian.new(flagger),
          ReviewableScore.types[:spam],
        )
      expect(result[:success]).to eq(true)

      unrelated_last_message =
        Fabricate(
          :chat_message,
          chat_channel: direct_message_channel,
          user: flagger,
          message: unrelated_last_message_text,
        )
      direct_message_channel.update!(last_message: unrelated_last_message)

      sign_in(moderator)
      get "/review.json", params: { type: "Chat::ReviewableMessage" }

      expect(response.status).to eq(200)
      expect(response.body).to include(flagged_message_text)
      expect(response.body).not_to include(unrelated_last_message_text)
    end
  end
end
