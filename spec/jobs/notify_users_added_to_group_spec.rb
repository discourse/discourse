# frozen_string_literal: true

describe Jobs::NotifyUsersAddedToGroup do
  fab!(:user)
  fab!(:group)

  describe "#execute" do
    it "sends the owner message when ownership notifications are requested" do
      group.add_owner(user)

      described_class.new.execute(user_ids: [user.id], group_id: group.id, owner: true)

      topic = Topic.private_messages.last
      expect(topic.title).to eq(
        I18n.t(
          "system_messages.user_added_to_group_as_owner.subject_template",
          group_name: group.name,
        ),
      )
      expect(topic.allowed_users).to include(user)
    end

    it "keeps the member message for jobs without an owner flag" do
      group.add(user)

      described_class.new.execute(user_ids: [user.id], group_id: group.id)

      topic = Topic.private_messages.last
      expect(topic.title).to eq(
        I18n.t(
          "system_messages.user_added_to_group_as_member.subject_template",
          group_name: group.name,
        ),
      )
      expect(topic.allowed_users).to include(user)
    end
  end
end
