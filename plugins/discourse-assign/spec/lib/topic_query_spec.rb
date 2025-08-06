# frozen_string_literal: true

require "topic_view"

describe TopicQuery do
  fab!(:user)
  fab!(:admin)
  fab!(:other_admin) { Fabricate(:admin) }

  fab!(:user_pm) { Fabricate(:private_message_topic, user: user) }
  fab!(:admin_pm) { Fabricate(:private_message_topic, user: admin) }
  fab!(:other_admin_pm) { Fabricate(:private_message_topic, user: other_admin) }

  fab!(:group)

  describe "#list_group_topics_assigned" do
    before do
      SiteSetting.assign_enabled = true

      [user, admin, other_admin].each { |user| group.add(user) }

      [user_pm, admin_pm, other_admin_pm].each { |topic| Fabricate(:post, topic: topic) }
      Fabricate(:topic_allowed_user, user: admin, topic: user_pm)

      Assigner.new(user_pm, Discourse.system_user).assign(admin)
      Assigner.new(admin_pm, Discourse.system_user).assign(admin)
      Assigner.new(other_admin_pm, Discourse.system_user).assign(other_admin)
    end

    it "includes PMs from all users" do
      expect(TopicQuery.new(user).list_group_topics_assigned(group).topics).to contain_exactly(
        user_pm,
      )
      expect(TopicQuery.new(admin).list_group_topics_assigned(group).topics).to contain_exactly(
        user_pm,
        admin_pm,
        other_admin_pm,
      )
      expect(
        TopicQuery.new(other_admin).list_group_topics_assigned(group).topics,
      ).to contain_exactly(user_pm, admin_pm, other_admin_pm)
    end
  end
end
