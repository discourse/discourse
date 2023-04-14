# frozen_string_literal: true

RSpec.describe TopicQuery::PrivateMessageLists do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }
  fab!(:user_3) { Fabricate(:user) }
  fab!(:user_4) { Fabricate(:user) }

  before_all { Group.refresh_automatic_groups! }

  fab!(:group) do
    Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone]).tap { |g| g.add(user_2) }
  end

  fab!(:group_2) do
    Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone]).tap { |g| g.add(user_4) }
  end

  fab!(:group_message) do
    create_post(
      user: user,
      target_group_names: [group.name],
      archetype: Archetype.private_message,
    ).topic
  end

  fab!(:group_message_2) do
    create_post(
      user: user_3,
      target_group_names: [group_2.name],
      archetype: Archetype.private_message,
    ).topic
  end

  fab!(:private_message) do
    create_post(
      user: user,
      target_usernames: [user_2.username],
      archetype: Archetype.private_message,
    ).topic
  end

  describe "#list_private_messages" do
    it "returns a list of all private messages that a user has access to" do
      topics = TopicQuery.new(nil).list_private_messages(user_2).topics

      expect(topics).to contain_exactly(private_message)
    end

    it "includes topics with moderator posts" do
      pm = Fabricate(:private_message_post, user: user_4).topic

      expect(TopicQuery.new(user_4).list_private_messages(user_4).topics).to be_empty

      pm.add_moderator_post(admin, "Thank you for your flag")

      expect(TopicQuery.new(user_4).list_private_messages(user_4).topics).to contain_exactly(pm)
    end
  end

  describe "#list_private_messages_group" do
    it "should return the right list for a group user" do
      group.add(user_2)

      topics =
        TopicQuery.new(nil, group_name: group.name).list_private_messages_group(user_2).topics

      expect(topics).to contain_exactly(group_message)
    end

    it "should return the right list for an admin not part of the group" do
      group.update!(name: group.name.capitalize)

      topics =
        TopicQuery
          .new(nil, group_name: group.name.upcase)
          .list_private_messages_group(Fabricate(:admin))
          .topics

      expect(topics).to contain_exactly(group_message)
    end

    it "should not allow a moderator not part of the group to view the group's messages" do
      topics =
        TopicQuery
          .new(nil, group_name: group.name)
          .list_private_messages_group(Fabricate(:moderator))
          .topics

      expect(topics).to eq([])
    end

    it "should not allow a user not part of the group to view the group's messages" do
      topics =
        TopicQuery
          .new(nil, group_name: group.name)
          .list_private_messages_group(Fabricate(:user))
          .topics

      expect(topics).to eq([])
    end

    context "when calculating minimum unread count for a topic" do
      before do
        group.update!(publish_read_state: true)
        group.add(user)
      end

      let(:listed_message) do
        TopicQuery.new(nil, group_name: group.name).list_private_messages_group(user).topics.first
      end

      it "returns the last read post number" do
        topic_group =
          TopicGroup.create!(topic: group_message, group: group, last_read_post_number: 10)

        expect(listed_message.last_read_post_number).to eq(topic_group.last_read_post_number)
      end
    end
  end

  describe "#list_private_messages_group_new" do
    it "returns a list of new private messages for a group that user is a part of" do
      topics =
        TopicQuery.new(nil, group_name: group.name).list_private_messages_group_new(user_2).topics

      expect(topics).to contain_exactly(group_message)
    end

    it "returns a list of new private messages for a group accounting for dismissed topics" do
      Fabricate(:dismissed_topic_user, topic: group_message, user: user_2)

      topics =
        TopicQuery.new(nil, group_name: group.name).list_private_messages_group_new(user_2).topics

      expect(topics).to eq([])
    end
  end

  describe "#list_private_messages_group_unread" do
    it "returns a list of unread private messages for a group that user is a part of" do
      topics =
        TopicQuery
          .new(nil, group_name: group.name)
          .list_private_messages_group_unread(user_2)
          .topics

      expect(topics).to eq([])

      TopicUser.find_by(user: user_2, topic: group_message).update!(last_read_post_number: 1)

      create_post(user: user, topic: group_message)

      topics =
        TopicQuery
          .new(nil, group_name: group.name)
          .list_private_messages_group_unread(user_2)
          .topics

      expect(topics).to contain_exactly(group_message)
    end
  end

  describe "#list_private_messages_unread" do
    fab!(:user) { Fabricate(:user) }
    fab!(:user_2) { Fabricate(:user) }

    before_all { Group.refresh_automatic_groups! }

    fab!(:pm) do
      create_post(
        user: user,
        target_usernames: [user_2.username],
        archetype: Archetype.private_message,
      ).topic
    end

    fab!(:pm_2) do
      create_post(
        user: user,
        target_usernames: [user_2.username],
        archetype: Archetype.private_message,
      ).topic
    end

    fab!(:pm_3) do
      create_post(
        user: user,
        target_usernames: [user_2.username],
        archetype: Archetype.private_message,
      ).topic
    end

    it "returns a list of private messages with unread posts that user is at least tracking" do
      freeze_time 1.minute.from_now do
        create_post(user: user_2, topic_id: pm.id)
        create_post(user: user_2, topic_id: pm_3.id)
      end

      TopicUser.find_by(user: user, topic: pm_3).update!(
        notification_level: TopicUser.notification_levels[:regular],
      )

      expect(TopicQuery.new(user).list_private_messages_unread(user).topics).to contain_exactly(pm)
    end
  end

  describe "#list_private_messages_new" do
    fab!(:user) { Fabricate(:user) }
    fab!(:user_2) { Fabricate(:user) }

    before_all { Group.refresh_automatic_groups! }

    fab!(:pm) do
      create_post(
        user: user,
        target_usernames: [user_2.username],
        archetype: Archetype.private_message,
      ).topic
    end

    fab!(:pm_2) do
      create_post(
        user: user,
        target_usernames: [user_2.username],
        archetype: Archetype.private_message,
      ).topic
    end

    it "returns a list of new private messages" do
      expect(TopicQuery.new(user_2).list_private_messages_new(user_2).topics).to contain_exactly(
        pm,
        pm_2,
      )
    end

    it "returns a list of new private messages accounting for muted tags" do
      tag = Fabricate(:tag)

      pm.tags << tag

      TagUser.create!(
        tag: tag,
        user: user_2,
        notification_level: TopicUser.notification_levels[:muted],
      )

      expect(TopicQuery.new(user_2).list_private_messages_new(user_2).topics).to contain_exactly(
        pm_2,
      )
    end

    it "returns a list of new private messages accounting for dismissed topics" do
      Fabricate(:dismissed_topic_user, topic: pm, user: user_2)

      expect(TopicQuery.new(user_2).list_private_messages_new(user_2).topics).to contain_exactly(
        pm_2,
      )
    end
  end

  describe "#private_messages_for" do
    it "returns a list of group private messages for a given user" do
      expect(TopicQuery.new(user, group_name: group.name).private_messages_for(user, :group)).to eq(
        [],
      )

      expect(
        TopicQuery.new(user_2, group_name: group.name).private_messages_for(user_2, :group),
      ).to contain_exactly(group_message)

      expect(
        TopicQuery.new(user_3, group_name: group_2.name).private_messages_for(user_3, :group),
      ).to eq([])

      expect(
        TopicQuery.new(user_4, group_name: group_2.name).private_messages_for(user_4, :group),
      ).to contain_exactly(group_message_2)
    end

    it "returns a list of personal private messages for a given user" do
      expect(TopicQuery.new(user).private_messages_for(user, :user)).to contain_exactly(
        private_message,
        group_message,
      )

      expect(TopicQuery.new(user_2).private_messages_for(user_2, :user)).to contain_exactly(
        private_message,
      )

      expect(TopicQuery.new(user_3).private_messages_for(user_3, :user)).to contain_exactly(
        group_message_2,
      )

      expect(TopicQuery.new(user_4).private_messages_for(user_4, :user)).to eq([])
    end

    it "returns a list of all private messages for a given user" do
      expect(TopicQuery.new(user).private_messages_for(user, :all)).to contain_exactly(
        private_message,
        group_message,
      )

      expect(TopicQuery.new(user_2).private_messages_for(user_2, :all)).to contain_exactly(
        private_message,
        group_message,
      )

      expect(TopicQuery.new(user_3).private_messages_for(user_3, :all)).to contain_exactly(
        group_message_2,
      )

      expect(TopicQuery.new(user_4).private_messages_for(user_4, :all)).to contain_exactly(
        group_message_2,
      )

      group_2.remove(user_4)

      expect(TopicQuery.new(user_4).private_messages_for(user_4, :all)).to eq([])
    end
  end

  describe "#list_private_messages_direct_and_groups" do
    it "returns a list of all personal and group private messages for a given user" do
      expect(
        TopicQuery.new(user_2).list_private_messages_direct_and_groups(user_2).topics,
      ).to contain_exactly(private_message, group_message)
    end

    it "returns a list of personal private messages and user watching group private messages for a given user when the `groups_notification_level` option is set" do
      expect(
        TopicQuery
          .new(user_2)
          .list_private_messages_direct_and_groups(
            user_2,
            groups_messages_notification_level: :watching,
          )
          .topics,
      ).to contain_exactly(private_message, group_message)

      TopicUser.find_by(user: user_2, topic: group_message).update!(
        notification_level: NotificationLevels.topic_levels[:regular],
      )

      expect(
        TopicQuery
          .new(user_2)
          .list_private_messages_direct_and_groups(
            user_2,
            groups_messages_notification_level: :watching,
          )
          .topics,
      ).to contain_exactly(private_message)
    end
  end
end
