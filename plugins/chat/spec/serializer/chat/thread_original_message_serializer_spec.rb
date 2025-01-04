# frozen_string_literal: true

RSpec.describe Chat::ThreadOriginalMessageSerializer do
  describe "#user" do
    fab!(:user_status)
    fab!(:user) { Fabricate(:user, user_status: user_status) }
    fab!(:message) { Fabricate(:chat_message, user: user) }

    subject(:serializer) { described_class.new(message, root: nil) }

    it "adds status to user if status is enabled" do
      SiteSetting.enable_user_status = true

      json = serializer.as_json

      expect(json[:user][:status]).to be_present
      expect(json[:user][:status][:description]).to eq(user_status.description)
      expect(json[:user][:status][:emoji]).to eq(user_status.emoji)
    end

    it "does not add status user if status is disabled" do
      SiteSetting.enable_user_status = false
      json = serializer.as_json
      expect(json[:user][:status]).to be_nil
    end
  end

  context "with mentions" do
    fab!(:user_status)
    fab!(:mentioned_user) { Fabricate(:user, user_status: user_status) }
    fab!(:message) do
      Fabricate(
        :chat_message,
        message:
          "there should be a mention here, but since we're fabricating objects it doesn't matter",
      )
    end
    fab!(:chat_mention) do
      Fabricate(:user_chat_mention, chat_message: message, user: mentioned_user)
    end

    subject(:serializer) { described_class.new(message, root: nil) }

    it "adds status to mentioned users if status is enabled" do
      SiteSetting.enable_user_status = true

      json = serializer.as_json

      expect(json[:mentioned_users][0][:status]).to be_present
      expect(json[:mentioned_users][0][:status][:description]).to eq(user_status.description)
      expect(json[:mentioned_users][0][:status][:emoji]).to eq(user_status.emoji)
    end

    it "does not add status to mentioned users if status is disabled" do
      SiteSetting.enable_user_status = false
      json = serializer.as_json
      expect(json[:mentioned_users][0][:status]).to be_nil
    end
  end
end
