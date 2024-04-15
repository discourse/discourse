# frozen_string_literal: true

describe "Reviewables", type: :system do
  fab!(:current_user) { Fabricate(:admin) }
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }

  before do
    chat_system_bootstrap(current_user)
    channel_1.add(current_user)
    sign_in(current_user)

    Chat::ReviewQueue.new.flag_message(
      message_1,
      current_user.guardian,
      ReviewableScore.types[:spam],
    )
  end

  context "when visiting reviews for messages " do
    it "lists the correct message" do
      visit("/review?type=Chat%3A%3AReviewableMessage")

      expect(page).to have_content(message_1.message)
    end
  end

  context "when the message is hard deleted" do
    before { message_1.destroy! }

    it "does not throw an error" do
      visit("/review?type=Chat%3A%3AReviewableMessage")

      expect(page).to have_selector(".reviewable-item.reviewable-chat-message")
    end

    it "adds the option to ignore the flag" do
      visit("/review?type=Chat%3A%3AReviewableMessage")

      expect(page).to have_selector(".reviewable-actions .chat-message-ignore")
    end
  end
end
