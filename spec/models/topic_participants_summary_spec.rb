# frozen_string_literal: true

require 'rails_helper'

describe TopicParticipantsSummary do
  describe '#summary' do
    let(:summary) { described_class.new(topic, user: topic_creator).summary }

    let(:topic) do
      Fabricate(:topic,
        user: topic_creator,
        archetype: Archetype::private_message,
        category_id: nil
      )
    end

    fab!(:topic_creator) { Fabricate(:user) }
    fab!(:user1) { Fabricate(:user) }
    fab!(:user2) { Fabricate(:user) }
    fab!(:user3) { Fabricate(:user) }
    fab!(:user4) { Fabricate(:user) }
    fab!(:user5) { Fabricate(:user) }
    fab!(:user6) { Fabricate(:user) }

    it "must never contains the user and at most 5 participants" do
      topic.allowed_user_ids = [user1.id, user2.id, user3.id, user4.id, user5.id, user6.id]
      expect(summary.map(&:user)).to eq([user1, user2, user3, user4, user5])
    end

  end
end
