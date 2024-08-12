# frozen_string_literal: true

RSpec.describe Statistics do
  describe "#participating_users" do
    it "returns no participating users by default" do
      pu = described_class.participating_users
      expect(pu[:last_day]).to eq(0)
      expect(pu[:"7_days"]).to eq(0)
      expect(pu[:"30_days"]).to eq(0)
    end

    it "returns users who have reacted to a post" do
      Fabricate(:user_action, action_type: UserAction::LIKE)
      expect(described_class.participating_users[:last_day]).to eq(1)
    end

    it "returns users who have created a new topic" do
      Fabricate(:user_action, action_type: UserAction::NEW_TOPIC)
      expect(described_class.participating_users[:last_day]).to eq(1)
    end

    it "returns users who have replied to a post" do
      Fabricate(:user_action, action_type: UserAction::REPLY)
      expect(described_class.participating_users[:last_day]).to eq(1)
    end

    it "returns users who have created a new PM" do
      Fabricate(:user_action, action_type: UserAction::NEW_PRIVATE_MESSAGE)
      expect(described_class.participating_users[:last_day]).to eq(1)
    end
  end
end
