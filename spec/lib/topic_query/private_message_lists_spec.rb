# frozen_string_literal: true

require 'rails_helper'

describe TopicQuery::PrivateMessageLists do
  fab!(:user) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }

  fab!(:group) do
    Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone]).tap do |g|
      g.add(user_2)
    end
  end

  fab!(:group_message) do
    create_post(
      user: user,
      target_group_names: [group.name],
      archetype: Archetype.private_message
    ).topic
  end

  fab!(:private_message) do
    create_post(
      user: user,
      target_usernames: [user_2.username],
      archetype: Archetype.private_message
    ).topic
  end

  describe '#list_private_messages_all' do
    it 'returns a list of all private messages that a user has access to' do
      topics = TopicQuery.new(nil).list_private_messages_all(user).topics

      expect(topics).to contain_exactly(group_message, private_message)
    end

    it 'does not include user or group archived messages' do
      UserArchivedMessage.archive!(user.id, group_message)
      UserArchivedMessage.archive!(user.id, private_message)

      topics = TopicQuery.new(nil).list_private_messages_all(user).topics

      expect(topics).to eq([])

      GroupArchivedMessage.archive!(user_2.id, group_message)

      topics = TopicQuery.new(nil).list_private_messages_all(user_2).topics

      expect(topics).to contain_exactly(private_message)
    end
  end

  describe '#list_private_messages_all_sent' do
    it 'returns a list of all private messages that a user has sent' do
      topics = TopicQuery.new(nil).list_private_messages_all_sent(user_2).topics

      expect(topics).to eq([])

      create_post(user: user_2, topic: private_message)

      topics = TopicQuery.new(nil).list_private_messages_all_sent(user_2).topics

      expect(topics).to contain_exactly(private_message)

      create_post(user: user_2, topic: group_message)

      topics = TopicQuery.new(nil).list_private_messages_all_sent(user_2).topics

      expect(topics).to contain_exactly(private_message, group_message)
    end

    it 'does not include user or group archived messages' do
      create_post(user: user_2, topic: private_message)
      create_post(user: user_2, topic: group_message)

      UserArchivedMessage.archive!(user_2.id, private_message)
      GroupArchivedMessage.archive!(user_2.id, group_message)

      topics = TopicQuery.new(nil).list_private_messages_all_sent(user_2).topics

      expect(topics).to eq([])
    end
  end

  describe '#list_private_messages_all_archive' do
    it 'returns a list of all private messages that has been archived' do
      UserArchivedMessage.archive!(user_2.id, private_message)
      GroupArchivedMessage.archive!(user_2.id, group_message)

      topics = TopicQuery.new(nil).list_private_messages_all_archive(user_2).topics

      expect(topics).to contain_exactly(private_message, group_message)
    end
  end

  describe '#list_private_messages_all_new' do
    it 'returns a list of new private messages' do
      topics = TopicQuery.new(nil).list_private_messages_all_new(user_2).topics

      expect(topics).to contain_exactly(private_message, group_message)

      TopicUser.find_by(user: user_2, topic: group_message).update!(
        last_read_post_number: 1
      )

      topics = TopicQuery.new(nil).list_private_messages_all_new(user_2).topics

      expect(topics).to contain_exactly(private_message)
    end
  end

  describe '#list_private_messages_all_unread' do
    it 'returns a list of unread private messages' do
      topics = TopicQuery.new(nil).list_private_messages_all_unread(user_2).topics

      expect(topics).to eq([])

      TopicUser.find_by(user: user_2, topic: group_message).update!(
        last_read_post_number: 1
      )

      create_post(user: user, topic: group_message)

      topics = TopicQuery.new(nil).list_private_messages_all_unread(user_2).topics

      expect(topics).to contain_exactly(group_message)
    end
  end

  describe '#list_private_messages' do
    it 'returns a list of all private messages that a user has access to' do
      topics = TopicQuery.new(nil).list_private_messages(user_2).topics

      expect(topics).to contain_exactly(private_message)
    end
  end

  describe '#list_private_messages_group' do
    it 'should return the right list for a group user' do
      group.add(user_2)

      topics = TopicQuery.new(nil, group_name: group.name)
        .list_private_messages_group(user_2)
        .topics

      expect(topics).to contain_exactly(group_message)
    end

    it 'should return the right list for an admin not part of the group' do
      group.update!(name: group.name.capitalize)

      topics = TopicQuery.new(nil, group_name: group.name.upcase)
        .list_private_messages_group(Fabricate(:admin))
        .topics

      expect(topics).to contain_exactly(group_message)
    end

    it "should not allow a moderator not part of the group to view the group's messages" do
      topics = TopicQuery.new(nil, group_name: group.name)
        .list_private_messages_group(Fabricate(:moderator))
        .topics

      expect(topics).to eq([])
    end

    it "should not allow a user not part of the group to view the group's messages" do
      topics = TopicQuery.new(nil, group_name: group.name)
        .list_private_messages_group(Fabricate(:user))
        .topics

      expect(topics).to eq([])
    end

    context "Calculating minimum unread count for a topic" do
      before do
        group.update!(publish_read_state: true)
        group.add(user)
      end

      let(:listed_message) do
        TopicQuery.new(nil, group_name: group.name)
          .list_private_messages_group(user)
          .topics.first
      end

      it 'returns the last read post number' do
        topic_group = TopicGroup.create!(
          topic: group_message, group: group, last_read_post_number: 10
        )

        expect(listed_message.last_read_post_number).to eq(topic_group.last_read_post_number)
      end
    end
  end

  describe '#list_private_messages_group_new' do
    it 'returns a list of new private messages for a group that user is a part of' do
      topics = TopicQuery.new(nil, group_name: group.name)
        .list_private_messages_group_new(user_2)
        .topics

      expect(topics).to contain_exactly(group_message)
    end
  end

  describe '#list_private_messages_group_unread' do
    it 'returns a list of unread private messages for a group that user is a part of' do
      topics = TopicQuery.new(nil, group_name: group.name)
        .list_private_messages_group_unread(user_2)
        .topics

      expect(topics).to eq([])

      TopicUser.find_by(user: user_2, topic: group_message).update!(
        last_read_post_number: 1
      )

      create_post(user: user, topic: group_message)

      topics = TopicQuery.new(nil, group_name: group.name)
        .list_private_messages_group_unread(user_2)
        .topics

      expect(topics).to contain_exactly(group_message)
    end
  end

  describe '#list_private_messages_unread' do
    fab!(:user) { Fabricate(:user) }
    fab!(:user_2) { Fabricate(:user) }

    fab!(:pm) do
      create_post(
        user: user,
        target_usernames: [user_2.username],
        archetype: Archetype.private_message
      ).topic
    end

    fab!(:pm_2) do
      create_post(
        user: user,
        target_usernames: [user_2.username],
        archetype: Archetype.private_message
      ).topic
    end

    fab!(:pm_3) do
      create_post(
        user: user,
        target_usernames: [user_2.username],
        archetype: Archetype.private_message
      ).topic
    end

    it 'returns a list of private messages with unread posts that user is at least tracking' do
      freeze_time 1.minute.from_now do
        create_post(user: user_2, topic_id: pm.id)
        create_post(user: user_2, topic_id: pm_3.id)
      end

      TopicUser.find_by(user: user, topic: pm_3).update!(
        notification_level: TopicUser.notification_levels[:regular]
      )

      expect(TopicQuery.new(user).list_private_messages_unread(user).topics)
        .to contain_exactly(pm)
    end
  end

  describe '#list_private_messages_new' do
    fab!(:user) { Fabricate(:user) }
    fab!(:user_2) { Fabricate(:user) }

    fab!(:pm) do
      create_post(
        user: user,
        target_usernames: [user_2.username],
        archetype: Archetype.private_message
      ).topic
    end

    it 'returns a list of new private messages' do
      expect(TopicQuery.new(user_2).list_private_messages_new(user_2).topics)
        .to contain_exactly(pm)
    end

    it 'returns a list of new private messages accounting for muted tags' do
      tag = Fabricate(:tag)

      pm.tags << tag

      TagUser.create!(
        tag: tag,
        user: user_2,
        notification_level: TopicUser.notification_levels[:muted]
      )

      expect(TopicQuery.new(user_2).list_private_messages_new(user_2).topics)
        .to eq([])
    end
  end
end
