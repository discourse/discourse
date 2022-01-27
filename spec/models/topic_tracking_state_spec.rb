# frozen_string_literal: true

require 'rails_helper'

describe TopicTrackingState do

  fab!(:user) { Fabricate(:user) }

  let(:post) do
    create_post
  end

  let(:topic) { post.topic }
  fab!(:private_message_post) { Fabricate(:private_message_post) }
  let(:private_message_topic) { private_message_post.topic }

  describe '#publish_latest' do
    it 'can correctly publish latest' do
      message = MessageBus.track_publish("/latest") do
        described_class.publish_latest(topic)
      end.first

      data = message.data

      expect(data["topic_id"]).to eq(topic.id)
      expect(data["message_type"]).to eq(described_class::LATEST_MESSAGE_TYPE)
      expect(data["payload"]["archetype"]).to eq(Archetype.default)
    end

    describe 'private message' do
      it 'should not publish any message' do
        messages = MessageBus.track_publish do
          described_class.publish_latest(private_message_topic)
        end

        expect(messages).to eq([])
      end
    end
  end

  describe '.publish_read' do
    it 'correctly publish read' do
      message = MessageBus.track_publish(described_class.unread_channel_key(post.user.id)) do
        TopicTrackingState.publish_read(post.topic_id, 1, post.user)
      end.first

      data = message.data

      expect(message.user_ids).to contain_exactly(post.user_id)
      expect(message.group_ids).to eq(nil)
      expect(data["topic_id"]).to eq(post.topic_id)
      expect(data["message_type"]).to eq(described_class::READ_MESSAGE_TYPE)
      expect(data["payload"]["last_read_post_number"]).to eq(1)
      expect(data["payload"]["highest_post_number"]).to eq(1)
      expect(data["payload"]["notification_level"]).to eq(nil)
    end

    it 'correctly publish read for staff' do
      create_post(
        raw: "this is a test post",
        topic: post.topic,
        post_type: Post.types[:whisper],
        user: Fabricate(:admin)
      )

      post.user.grant_admin!

      message = MessageBus.track_publish(described_class.unread_channel_key(post.user.id)) do
        TopicTrackingState.publish_read(post.topic_id, 1, post.user)
      end.first

      data = message.data

      expect(data["payload"]["highest_post_number"]).to eq(2)
    end
  end

  describe '#publish_unread' do
    it "can correctly publish unread" do
      message = MessageBus.track_publish(described_class.unread_channel_key(post.user.id)) do
        TopicTrackingState.publish_unread(post)
      end.first

      data = message.data

      expect(message.user_ids).to contain_exactly(post.user.id)
      expect(message.group_ids).to eq(nil)
      expect(data["topic_id"]).to eq(topic.id)
      expect(data["message_type"]).to eq(described_class::UNREAD_MESSAGE_TYPE)
      expect(data["payload"]["archetype"]).to eq(Archetype.default)
    end

    it "is not erroring when user_stat is missing" do
      post.user.user_stat.destroy!
      message = MessageBus.track_publish(described_class.unread_channel_key(post.user.id)) do
        TopicTrackingState.publish_unread(post)
      end.first

      data = message.data

      expect(message.user_ids).to contain_exactly(post.user.id)
    end

    it "does not publish whisper post to non-staff users" do
      post.update!(post_type: Post.types[:whisper])

      messages = MessageBus.track_publish(described_class.unread_channel_key(post.user_id)) do
        TopicTrackingState.publish_unread(post)
      end

      expect(messages).to eq([])

      post.user.grant_admin!

      message = MessageBus.track_publish(described_class.unread_channel_key(post.user_id)) do
        TopicTrackingState.publish_unread(post)
      end.first

      expect(message.user_ids).to contain_exactly(post.user_id)
      expect(message.group_ids).to eq(nil)
    end

    it "correctly publishes unread for a post in a restricted category" do
      group = Fabricate(:group)
      category = Fabricate(:private_category, group: group)

      post.topic.update!(category: category)

      messages = MessageBus.track_publish(described_class.unread_channel_key(post.user_id)) do
        TopicTrackingState.publish_unread(post)
      end

      expect(messages).to eq([])

      group.add(post.user)

      message = MessageBus.track_publish(described_class.unread_channel_key(post.user_id)) do
        TopicTrackingState.publish_unread(post)
      end.first

      expect(message.user_ids).to contain_exactly(post.user_id)
      expect(message.group_ids).to eq(nil)
    end

    describe 'for a private message' do
      before do
        TopicUser.change(
          private_message_topic.allowed_users.first.id,
          private_message_topic.id,
          notification_level: TopicUser.notification_levels[:tracking]
        )
      end

      it 'should not publish any message' do
        messages = MessageBus.track_publish do
          TopicTrackingState.publish_unread(private_message_post)
        end

        expect(messages).to eq([])
      end
    end
  end

  describe '#publish_muted' do
    let(:user) do
      Fabricate(:user, last_seen_at: Date.today)
    end
    let(:post) do
      create_post(user: user)
    end

    it 'can correctly publish muted' do
      TopicUser.find_by(topic: topic, user: post.user).update(notification_level: 0)
      messages = MessageBus.track_publish("/latest") do
        TopicTrackingState.publish_muted(topic)
      end

      muted_message = messages.find { |message| message.data["message_type"] == "muted" }

      expect(muted_message.data["topic_id"]).to eq(topic.id)
      expect(muted_message.data["message_type"]).to eq(described_class::MUTED_MESSAGE_TYPE)
    end

    it 'should not publish any message when notification level is not muted' do
      messages = MessageBus.track_publish("/latest") do
        TopicTrackingState.publish_muted(topic)
      end
      muted_messages = messages.select { |message| message.data["message_type"] == "muted" }

      expect(muted_messages).to eq([])
    end

    it 'should not publish any message when the user was not seen in the last 7 days' do
      TopicUser.find_by(topic: topic, user: post.user).update(notification_level: 0)
      post.user.update(last_seen_at: 8.days.ago)
      messages = MessageBus.track_publish("/latest") do
        TopicTrackingState.publish_muted(topic)
      end
      muted_messages = messages.select { |message| message.data["message_type"] == "muted" }
      expect(muted_messages).to eq([])
    end
  end

  describe '#publish_unmuted' do
    let(:user) do
      Fabricate(:user, last_seen_at: Date.today)
    end
    let(:second_user) do
      Fabricate(:user, last_seen_at: Date.today)
    end
    let(:third_user) do
      Fabricate(:user, last_seen_at: Date.today)
    end
    let(:post) do
      create_post(user: user)
    end

    it 'can correctly publish unmuted' do
      Fabricate(:topic_tag, topic: topic)
      SiteSetting.mute_all_categories_by_default = true
      TopicUser.find_by(topic: topic, user: post.user).update(notification_level: 1)
      CategoryUser.create!(category: topic.category, user: second_user, notification_level: 1)
      TagUser.create!(tag: topic.tags.first, user: third_user, notification_level: 1)
      TagUser.create!(tag: topic.tags.first, user: Fabricate(:user), notification_level: 0)
      messages = MessageBus.track_publish("/latest") do
        TopicTrackingState.publish_unmuted(topic)
      end

      unmuted_message = messages.find { |message| message.data["message_type"] == "unmuted" }
      expect(unmuted_message.user_ids.sort).to eq([user.id, second_user.id, third_user.id].sort)
      expect(unmuted_message.data["topic_id"]).to eq(topic.id)
      expect(unmuted_message.data["message_type"]).to eq(described_class::UNMUTED_MESSAGE_TYPE)
    end

    it 'should not publish any message when notification level is not muted' do
      SiteSetting.mute_all_categories_by_default = true
      TopicUser.find_by(topic: topic, user: post.user).update(notification_level: 0)
      messages = MessageBus.track_publish("/latest") do
        TopicTrackingState.publish_unmuted(topic)
      end
      unmuted_messages = messages.select { |message| message.data["message_type"] == "unmuted" }

      expect(unmuted_messages).to eq([])
    end

    it 'should not publish any message when the user was not seen in the last 7 days' do
      TopicUser.find_by(topic: topic, user: post.user).update(notification_level: 1)
      post.user.update(last_seen_at: 8.days.ago)
      messages = MessageBus.track_publish("/latest") do
        TopicTrackingState.publish_unmuted(topic)
      end
      unmuted_messages = messages.select { |message| message.data["message_type"] == "unmuted" }
      expect(unmuted_messages).to eq([])
    end
  end

  describe '#publish_read_private_message' do
    fab!(:group) { Fabricate(:group) }
    let(:read_topic_key) { "/private-messages/unread-indicator/#{group_message.id}" }
    let(:read_post_key) { "/topic/#{group_message.id}" }
    let(:latest_post_number) { 3 }
    let(:group_message) { Fabricate(:private_message_topic,
        allowed_groups: [group],
        topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: user)],
        highest_post_number: latest_post_number
      )
    }
    let!(:post) {
      Fabricate(:post, topic: group_message, post_number: latest_post_number)
    }

    before do
      group.add(user)
    end

    it 'does not trigger a read count update if no allowed groups have the option enabled' do
      messages = MessageBus.track_publish(read_post_key) do
        TopicTrackingState.publish_read_indicator_on_read(group_message.id, latest_post_number, user.id)
      end

      expect(messages).to be_empty
    end

    context 'when the read indicator is enabled' do
      before { group.update!(publish_read_state: true) }

      it 'publishes a message to hide the unread indicator' do
        message = MessageBus.track_publish(read_topic_key) do
          TopicTrackingState.publish_read_indicator_on_read(group_message.id, latest_post_number, user.id)
        end.first

        expect(message.data['topic_id']).to eq group_message.id
        expect(message.data['show_indicator']).to eq false
      end

      it 'publishes a message to show the unread indicator when a non-member creates a new post' do
        allowed_user = Fabricate(:topic_allowed_user, topic: group_message)
        message = MessageBus.track_publish(read_topic_key) do
          TopicTrackingState.publish_read_indicator_on_write(group_message.id, latest_post_number, allowed_user.id)
        end.first

        expect(message.data['topic_id']).to eq group_message.id
        expect(message.data['show_indicator']).to eq true
      end

      it 'does not publish the unread indicator if the message is not the last one' do
        not_last_post_number = latest_post_number - 1
        Fabricate(:post, topic: group_message, post_number: not_last_post_number)
        messages = MessageBus.track_publish(read_topic_key) do
          TopicTrackingState.publish_read_indicator_on_read(group_message.id, not_last_post_number, user.id)
        end

        expect(messages).to be_empty
      end

      it 'does not publish the read indicator if the user is not a group member' do
        allowed_user = Fabricate(:topic_allowed_user, topic: group_message)
        messages = MessageBus.track_publish(read_topic_key) do
          TopicTrackingState.publish_read_indicator_on_read(group_message.id, latest_post_number, allowed_user.user_id)
        end

        expect(messages).to be_empty
      end

      it 'publish a read count update to every client' do
        message = MessageBus.track_publish(read_post_key) do
          TopicTrackingState.publish_read_indicator_on_read(group_message.id, latest_post_number, user.id)
        end.first

        expect(message.data[:type]).to eq :read
      end
    end
  end

  it "correctly handles muted categories" do
    post

    report = TopicTrackingState.report(user)
    expect(report.length).to eq(1)

    CategoryUser.create!(user_id: user.id,
                         notification_level: CategoryUser.notification_levels[:muted],
                         category_id: post.topic.category_id
                         )

    create_post(topic_id: post.topic_id)

    report = TopicTrackingState.report(user)
    expect(report.length).to eq(0)

    TopicUser.create!(user_id: user.id, topic_id: post.topic_id, last_read_post_number: 1, notification_level: 3)

    report = TopicTrackingState.report(user)
    expect(report.length).to eq(1)
  end

  it "works when categories are default muted" do
    SiteSetting.mute_all_categories_by_default = true

    post

    report = TopicTrackingState.report(user)
    expect(report.length).to eq(0)

    CategoryUser.create!(user_id: user.id,
                         notification_level: CategoryUser.notification_levels[:regular],
                         category_id: post.topic.category_id
                         )

    create_post(topic_id: post.topic_id)

    report = TopicTrackingState.report(user)
    expect(report.length).to eq(1)
  end

  context 'muted tags' do
    it "remove_muted_tags_from_latest is set to always" do
      SiteSetting.remove_muted_tags_from_latest = 'always'
      tag1 = Fabricate(:tag)
      tag2 = Fabricate(:tag)
      Fabricate(:topic_tag, tag: tag1, topic: topic)
      Fabricate(:topic_tag, tag: tag2, topic: topic)
      post

      report = TopicTrackingState.report(user)
      expect(report.length).to eq(1)

      TagUser.create!(user_id: user.id,
                      notification_level: TagUser.notification_levels[:muted],
                      tag_id: tag1.id
                     )

      report = TopicTrackingState.report(user)
      expect(report.length).to eq(0)

      TopicTag.where(topic_id: topic.id).delete_all

      report = TopicTrackingState.report(user)
      expect(report.length).to eq(1)
    end

    it "remove_muted_tags_from_latest is set to only_muted" do
      SiteSetting.remove_muted_tags_from_latest = 'only_muted'
      tag1 = Fabricate(:tag)
      tag2 = Fabricate(:tag)
      Fabricate(:topic_tag, tag: tag1, topic: topic)
      Fabricate(:topic_tag, tag: tag2, topic: topic)
      post

      report = TopicTrackingState.report(user)
      expect(report.length).to eq(1)

      TagUser.create!(user_id: user.id,
                      notification_level: TagUser.notification_levels[:muted],
                      tag_id: tag1.id
                     )

      report = TopicTrackingState.report(user)
      expect(report.length).to eq(1)

      TagUser.create!(user_id: user.id,
                      notification_level: TagUser.notification_levels[:muted],
                      tag_id: tag2.id
                     )

      report = TopicTrackingState.report(user)
      expect(report.length).to eq(0)

      TopicTag.where(topic_id: topic.id).delete_all

      report = TopicTrackingState.report(user)
      expect(report.length).to eq(1)
    end

    it "remove_muted_tags_from_latest is set to never" do
      SiteSetting.remove_muted_tags_from_latest = 'never'
      tag1 = Fabricate(:tag)
      Fabricate(:topic_tag, tag: tag1, topic: topic)
      post

      report = TopicTrackingState.report(user)
      expect(report.length).to eq(1)

      TagUser.create!(user_id: user.id,
                      notification_level: TagUser.notification_levels[:muted],
                      tag_id: tag1.id
                     )

      report = TopicTrackingState.report(user)
      expect(report.length).to eq(1)
    end
  end

  it "correctly handles dismissed topics" do
    freeze_time 1.minute.ago
    user.update!(created_at: Time.now)
    post

    report = TopicTrackingState.report(user)
    expect(report.length).to eq(1)

    DismissedTopicUser.create!(user_id: user.id, topic_id: post.topic_id, created_at: Time.zone.now)
    CategoryUser.create!(user_id: user.id,
                         notification_level: CategoryUser.notification_levels[:regular],
                         category_id: post.topic.category_id,
                         last_seen_at: post.topic.created_at
                         )

    report = TopicTrackingState.report(user)
    expect(report.length).to eq(0)
  end

  it "correctly handles capping" do
    post1 = create_post
    Fabricate(:post, topic: post1.topic)

    post2 = create_post
    Fabricate(:post, topic: post2.topic)

    post3 = create_post
    Fabricate(:post, topic: post3.topic)

    tracking = {
      notification_level: TopicUser.notification_levels[:tracking],
      last_read_post_number: 1,
    }

    TopicUser.change(user.id, post1.topic_id, tracking)
    TopicUser.change(user.id, post2.topic_id, tracking)
    TopicUser.change(user.id, post3.topic_id, tracking)

    report = TopicTrackingState.report(user)
    expect(report.length).to eq(3)

  end

  context "tag support" do
    after do
      # this is a bit of an odd hook, but this is a global change
      # used by plugins that leverage tagging heavily and need
      # tag information in topic tracking state
      TopicTrackingState.include_tags_in_report = false
    end

    it "correctly handles tags" do
      SiteSetting.tagging_enabled = true

      post.topic.notifier.watch_topic!(post.topic.user_id)

      DiscourseTagging.tag_topic_by_names(
        post.topic,
        Guardian.new(Discourse.system_user),
        ['bananas', 'apples']
      )

      TopicTrackingState.include_tags_in_report = true

      report = TopicTrackingState.report(user)
      expect(report.length).to eq(1)
      row = report[0]
      expect(row.tags).to contain_exactly("apples", "bananas")

      TopicTrackingState.include_tags_in_report = false

      report = TopicTrackingState.report(user)
      expect(report.length).to eq(1)
      row = report[0]
      expect(row.respond_to? :tags).to eq(false)
    end
  end

  it "correctly gets the tracking state" do
    report = TopicTrackingState.report(user)
    expect(report.length).to eq(0)

    post.topic.notifier.watch_topic!(post.topic.user_id)

    report = TopicTrackingState.report(user)

    expect(report.length).to eq(1)
    row = report[0]

    expect(row.topic_id).to eq(post.topic_id)
    expect(row.highest_post_number).to eq(1)
    expect(row.last_read_post_number).to eq(nil)
    expect(row.user_id).to eq(user.id)

    # lets not leak out random users
    expect(TopicTrackingState.report(post.user)).to be_empty

    # lets not return anything if we scope on non-existing topic
    expect(TopicTrackingState.report(user, post.topic_id + 1)).to be_empty

    # when we reply the poster should have an unread row
    create_post(user: user, topic: post.topic)

    report = TopicTrackingState.report(user)
    expect(report.length).to eq(0)

    report = TopicTrackingState.report(post.user)
    expect(report.length).to eq(1)

    row = report[0]

    expect(row.topic_id).to eq(post.topic_id)
    expect(row.highest_post_number).to eq(2)
    expect(row.last_read_post_number).to eq(1)
    expect(row.user_id).to eq(post.user_id)

    # when we have no permission to see a category, don't show its stats
    category = Fabricate(:category, read_restricted: true)

    post.topic.category_id = category.id
    post.topic.save

    expect(TopicTrackingState.report(post.user)).to be_empty
    expect(TopicTrackingState.report(user)).to be_empty
  end

  describe ".report" do
    it "correctly reports topics with staff posts" do
      create_post(
        raw: "this is a test post",
        topic: topic,
        user: post.user
      )

      create_post(
        raw: "this is a test post",
        topic: topic,
        post_type: Post.types[:whisper],
        user: user
      )

      post.user.grant_admin!

      state = TopicTrackingState.report(post.user)

      expect(state.map(&:topic_id)).to contain_exactly(topic.id)
    end
  end
end
