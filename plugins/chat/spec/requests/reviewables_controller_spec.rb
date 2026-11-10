# frozen_string_literal: true

RSpec.describe ReviewablesController do
  fab!(:moderator)
  fab!(:message_author) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:flagger) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:restricted_group) { Fabricate(:group, users: [flagger]) }
  fab!(:restricted_category) { Fabricate(:private_category, group: restricted_group) }
  fab!(:restricted_channel) { Fabricate(:category_channel, chatable: restricted_category) }
  fab!(:restricted_message) do
    Fabricate(
      :chat_message,
      chat_channel: restricted_channel,
      user: message_author,
      message: "restricted category chat content",
    )
  end
  fab!(:direct_message_channel) do
    Fabricate(:direct_message_channel, users: [message_author, flagger])
  end

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.chat_message_flag_allowed_groups = Group::AUTO_GROUPS[:everyone]
  end

  describe "#index" do
    it "does not expose flagged messages from category channels a moderator cannot see" do
      expect(moderator.guardian.can_preview_chat_channel?(restricted_channel)).to eq(false)

      result =
        Chat::ReviewQueue.new.flag_message(
          restricted_message,
          Guardian.new(flagger),
          ReviewableScore.types[:spam],
        )
      expect(result[:success]).to eq(true)

      sign_in(moderator)
      get "/review.json", params: { type: "Chat::ReviewableMessage" }

      expect(response.status).to eq(200)
      listed_ids = response.parsed_body["reviewables"].map { |reviewable| reviewable["id"] }
      expect(listed_ids).not_to include(result[:reviewable].id)
      expect(response.body).not_to include(restricted_message.message)
      expect(response.parsed_body["meta"]["unseen_reviewable_count"]).to eq(0)
    end

    it "shows category-channel reviewables to an authorized moderator and administrator" do
      result =
        Chat::ReviewQueue.new.flag_message(
          restricted_message,
          Guardian.new(flagger),
          ReviewableScore.types[:spam],
        )
      authorized_moderator = Fabricate(:moderator)
      admin = Fabricate(:admin)
      restricted_group.add(authorized_moderator)

      [authorized_moderator, admin].each do |reviewer|
        expect(reviewer.guardian.can_preview_chat_channel?(restricted_channel)).to eq(true)

        sign_in(reviewer)
        get "/review.json", params: { type: "Chat::ReviewableMessage" }

        expect(response.status).to eq(200)
        listed_ids = response.parsed_body["reviewables"].map { |reviewable| reviewable["id"] }
        expect(listed_ids).to include(result[:reviewable].id)
        expect(response.body).to include(restricted_message.message)
      end
    end

    it "retains direct-message reviewables when a moderator cannot access any categories" do
      Category.update_all(read_restricted: true)
      expect(moderator.guardian.allowed_category_ids).to eq([])

      category_result =
        Chat::ReviewQueue.new.flag_message(
          restricted_message,
          Guardian.new(flagger),
          ReviewableScore.types[:spam],
        )
      direct_message =
        Fabricate(
          :chat_message,
          chat_channel: direct_message_channel,
          user: message_author,
          message: "direct-message reviewable content",
        )
      direct_message_result =
        Chat::ReviewQueue.new.flag_message(
          direct_message,
          Guardian.new(flagger),
          ReviewableScore.types[:spam],
        )

      expect(category_result[:success]).to eq(true)
      expect(direct_message_result[:success]).to eq(true)

      sign_in(moderator)
      get "/review.json", params: { type: "Chat::ReviewableMessage" }

      expect(response.status).to eq(200)
      listed_ids = response.parsed_body["reviewables"].map { |reviewable| reviewable["id"] }
      expect(listed_ids).to include(direct_message_result[:reviewable].id)
      expect(listed_ids).not_to include(category_result[:reviewable].id)
      expect(response.body).to include(direct_message.message)
      expect(response.body).not_to include(restricted_message.message)

      get "/review/#{category_result[:reviewable].id}.json"

      expect(response.status).to eq(404)
      expect(response.body).not_to include(restricted_message.message)
    end

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
