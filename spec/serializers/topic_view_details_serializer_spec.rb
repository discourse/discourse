# frozen_string_literal: true

describe TopicViewDetailsSerializer do
  describe '#allowed_users' do
    it "add the current user to the allowed user's list even if they are an allowed group member" do
      participant = Fabricate(:user)
      another_participant = Fabricate(:user)

      participant_group = Fabricate(:group)
      participant_group.add(participant)
      participant_group.add(another_participant)

      pm = Fabricate(:private_message_topic,
        topic_allowed_users: [
          Fabricate.build(:topic_allowed_user, user: participant),
          Fabricate.build(:topic_allowed_user, user: another_participant)
        ],
        topic_allowed_groups: [Fabricate.build(:topic_allowed_group, group: participant_group)]
      )

      serializer = described_class.new(TopicView.new(pm, participant), scope: Guardian.new(participant))
      allowed_users = serializer.as_json.dig(:topic_view_details, :allowed_users).map { |u| u[:id] }

      expect(allowed_users).to contain_exactly(participant.id)
    end
  end
end
