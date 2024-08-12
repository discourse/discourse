# frozen_string_literal: true

RSpec.describe Statistics do
  describe "#participating_users" do
    it "returns users who have sent a chat message" do
      Fabricate(:chat_message)
      expect(described_class.participating_users[:last_day]).to eq(1)
    end

    it "returns users who have reacted to a chat message" do
      Fabricate(:chat_message_reaction)
      expect(described_class.participating_users[:last_day]).to eq(2) # 2 because the chat message creator is also counted
    end
  end
end
