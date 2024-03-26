# frozen_string_literal: true

describe Chat::ThreadOriginalMessageSerializer do
  subject(:serializer) { described_class.new(message_1, scope: guardian, root: nil) }

  fab!(:message_1) { Fabricate(:chat_message) }
  fab!(:guardian_user) { Fabricate(:user) }

  let(:guardian) { Guardian.new(guardian_user) }

  describe "#mentioned_users" do
    it "is limited by max_mentions_per_chat_message setting" do
      Fabricate.times(2, :user_chat_mention, chat_message: message_1)
      SiteSetting.max_mentions_per_chat_message = 1

      expect(serializer.as_json[:mentioned_users].length).to eq(1)
    end
  end
end
