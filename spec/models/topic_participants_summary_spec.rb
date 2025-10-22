# frozen_string_literal: true

RSpec.describe TopicParticipantsSummary do
  describe "#summary" do
    let(:summary) { described_class.new(topic, user: topic_creator).summary }

    let(:topic) do
      Fabricate(:topic, user: topic_creator, archetype: Archetype.private_message, category_id: nil)
    end

    fab!(:topic_creator, :user)
    fab!(:user1, :user)
    fab!(:user2, :user)
    fab!(:user3, :user)
    fab!(:user4, :user)
    fab!(:user5, :user)
    fab!(:user6, :user)

    it "must never contains the user and at most 5 participants" do
      topic.allowed_user_ids = [user1.id, user2.id, user3.id, user4.id, user5.id, user6.id]
      expect(summary.map(&:user)).to eq([user1, user2, user3, user4, user5])
    end
  end
end
