# frozen_string_literal: true

RSpec.describe TopicTrackingState do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:whisperers_group) { Fabricate(:group) }
  fab!(:private_message_post)
  let(:private_message_topic) { private_message_post.topic }
  let(:post) { create_post }
  let(:topic) { post.topic }

  shared_examples "does not publish message for private topics" do |method|
    it "should not publish any message for a private topic" do
      messages =
        MessageBus.track_publish { described_class.public_send(method, private_message_topic) }

      expect(messages).to eq([])
    end
  end

  shared_examples "publishes message to right groups and users" do |message_bus_channel, method|
    fab!(:public_category) { Fabricate(:category, read_restricted: false) }
    fab!(:topic_in_public_category) { Fabricate(:topic, category: public_category) }
    fab!(:group)
    fab!(:read_restricted_category_with_groups) { Fabricate(:private_category, group: group) }

    fab!(:topic_in_read_restricted_category_with_groups) do
      Fabricate(:topic, category: read_restricted_category_with_groups)
    end

    fab!(:read_restricted_category_with_no_groups) { Fabricate(:category, read_restricted: true) }

    fab!(:topic_in_read_restricted_category_with_no_groups) do
      Fabricate(:topic, category: read_restricted_category_with_no_groups)
    end

    it "should publish message to everyone for a topic in a category that is not read restricted" do
      message =
        MessageBus
          .track_publish(message_bus_channel) do
            described_class.public_send(method, topic_in_public_category)
          end
          .first

      data = message.data

      expect(data["topic_id"]).to eq(topic_in_public_category.id)
      expect(message.group_ids).to eq(nil)
      expect(message.user_ids).to eq(nil)
    end

    it "should publish message only to admin group and groups that have permission to read a category when topic is in category that is restricted to certain groups" do
      message =
        MessageBus
          .track_publish(message_bus_channel) do
            described_class.public_send(method, topic_in_read_restricted_category_with_groups)
          end
          .first

      data = message.data

      expect(data["topic_id"]).to eq(topic_in_read_restricted_category_with_groups.id)
      expect(message.group_ids).to contain_exactly(Group::AUTO_GROUPS[:admins], group.id)
      expect(message.user_ids).to eq(nil)
    end

    it "should publish message only to admin group when topic is in category that is read restricted but no groups have been granted access" do
      message =
        MessageBus
          .track_publish(message_bus_channel) do
            described_class.public_send(method, topic_in_read_restricted_category_with_no_groups)
          end
          .first

      data = message.data

      expect(data["topic_id"]).to eq(topic_in_read_restricted_category_with_no_groups.id)
      expect(message.group_ids).to contain_exactly(Group::AUTO_GROUPS[:admins])
      expect(message.user_ids).to eq(nil)
    end
  end

  describe ".publish_new" do
    include_examples("publishes message to right groups and users", "/new", :publish_new)
    include_examples("does not publish message for private topics", :publish_new)
  end

  describe ".publish_latest" do
    include_examples("publishes message to right groups and users", "/latest", :publish_latest)
    include_examples("does not publish message for private topics", :publish_latest)

    it "can correctly publish latest" do
      message = MessageBus.track_publish("/latest") { described_class.publish_latest(topic) }.first

      data = message.data

      expect(data["topic_id"]).to eq(topic.id)
      expect(data["message_type"]).to eq(described_class::LATEST_MESSAGE_TYPE)
      expect(data["payload"]["archetype"]).to eq(Archetype.default)
      expect(message.group_ids).to eq(nil)
      expect(message.user_ids).to eq(nil)
    end

    it "publishes whisper post to staff users and members of whisperers group" do
      whisperers_group = Fabricate(:group)
      Fabricate(:user, groups: [whisperers_group])
      Fabricate(:topic_user_watching, topic: topic, user: user)
      SiteSetting.whispers_allowed_groups = "#{whisperers_group.id}"
      post.update!(post_type: Post.types[:whisper])

      message =
        MessageBus
          .track_publish("/latest") { TopicTrackingState.publish_latest(post.topic, true) }
          .first

      expect(message.group_ids).to contain_exactly(whisperers_group.id, Group::AUTO_GROUPS[:staff])
    end
  end

  describe ".publish_read" do
    it "correctly publish read" do
      message =
        MessageBus
          .track_publish(described_class.unread_channel_key(post.user.id)) do
            TopicTrackingState.publish_read(post.topic_id, 1, post.user)
          end
          .first

      data = message.data

      expect(message.user_ids).to contain_exactly(post.user_id)
      expect(message.group_ids).to eq(nil)
      expect(data["topic_id"]).to eq(post.topic_id)
      expect(data["message_type"]).to eq(described_class::READ_MESSAGE_TYPE)
      expect(data["payload"]["last_read_post_number"]).to eq(1)
      expect(data["payload"]["highest_post_number"]).to eq(1)
      expect(data["payload"]["notification_level"]).to eq(nil)
    end

    it "correctly publish read for staff" do
      SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}"
      create_post(
        raw: "this is a test post",
        topic: post.topic,
        post_type: Post.types[:whisper],
        user: Fabricate(:admin),
      )

      post.user.grant_admin!

      message =
        MessageBus
          .track_publish(described_class.unread_channel_key(post.user.id)) do
            TopicTrackingState.publish_read(post.topic_id, 1, post.user)
          end
          .first

      data = message.data

      expect(data["payload"]["highest_post_number"]).to eq(2)
    end
  end

  describe "#publish_unread" do
    let(:other_user) { Fabricate(:user) }

    before { Fabricate(:topic_user_watching, topic: topic, user: other_user) }

    it "can correctly publish unread" do
      message =
        MessageBus.track_publish("/unread") { TopicTrackingState.publish_unread(post) }.first

      data = message.data

      expect(message.user_ids).to contain_exactly(other_user.id)
      expect(message.group_ids).to eq(nil)
      expect(data["topic_id"]).to eq(topic.id)
      expect(data["message_type"]).to eq(described_class::UNREAD_MESSAGE_TYPE)
      expect(data["payload"]["archetype"]).to eq(Archetype.default)
    end

    it "does not publish unread to the user who created the post" do
      message =
        MessageBus.track_publish("/unread") { TopicTrackingState.publish_unread(post) }.first

      data = message.data

      expect(message.user_ids).not_to include(post.user_id)
      expect(data["topic_id"]).to eq(topic.id)
      expect(data["message_type"]).to eq(described_class::UNREAD_MESSAGE_TYPE)
      expect(data["payload"]["archetype"]).to eq(Archetype.default)
    end

    it "is not erroring when user_stat is missing" do
      post.user.user_stat.destroy!
      message =
        MessageBus.track_publish("/unread") { TopicTrackingState.publish_unread(post) }.first

      data = message.data

      expect(message.user_ids).to contain_exactly(other_user.id)
    end

    it "publishes whisper post to staff users and members of whisperers group" do
      whisperers_group = Fabricate(:group)
      Fabricate(:topic_user_watching, topic: topic, user: user)
      SiteSetting.whispers_allowed_groups = "#{whisperers_group.id}"
      post.update!(post_type: Post.types[:whisper])

      messages = MessageBus.track_publish("/unread") { TopicTrackingState.publish_unread(post) }

      expect(messages).to eq([])

      user.groups << whisperers_group
      other_user.grant_admin!

      message =
        MessageBus.track_publish("/unread") { TopicTrackingState.publish_unread(post) }.first

      expect(message.user_ids).to contain_exactly(user.id, other_user.id)
      expect(message.group_ids).to eq(nil)
    end

    it "does not publish whisper post to non-staff users" do
      SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}"
      post.update!(post_type: Post.types[:whisper])

      messages = MessageBus.track_publish("/unread") { TopicTrackingState.publish_unread(post) }

      expect(messages).to eq([])

      other_user.grant_admin!

      message =
        MessageBus.track_publish("/unread") { TopicTrackingState.publish_unread(post) }.first

      expect(message.user_ids).to contain_exactly(other_user.id)
      expect(message.group_ids).to eq(nil)
    end

    it "correctly publishes unread for a post in a restricted category" do
      group = Fabricate(:group)
      category = Fabricate(:private_category, group: group)

      post.topic.update!(category: category)

      messages = MessageBus.track_publish("/unread") { TopicTrackingState.publish_unread(post) }

      expect(messages).to eq([])

      group.add(other_user)

      message =
        MessageBus.track_publish("/unread") { TopicTrackingState.publish_unread(post) }.first

      expect(message.user_ids).to contain_exactly(other_user.id)
      expect(message.group_ids).to eq(nil)
    end

    describe "for a private message" do
      before do
        TopicUser.change(
          private_message_topic.allowed_users.first.id,
          private_message_topic.id,
          notification_level: TopicUser.notification_levels[:tracking],
        )
      end

      it "should not publish any message" do
        messages =
          MessageBus.track_publish { TopicTrackingState.publish_unread(private_message_post) }

        expect(messages).to eq([])
      end
    end
  end

  describe "#publish_muted" do
    let(:user) { Fabricate(:user, last_seen_at: Date.today, refresh_auto_groups: true) }
    let(:post) { create_post(user: user) }

    include_examples("does not publish message for private topics", :publish_muted)

    it "can correctly publish muted" do
      TopicUser.find_by(topic: topic, user: post.user).update(notification_level: 0)
      messages = MessageBus.track_publish("/latest") { TopicTrackingState.publish_muted(topic) }

      muted_message = messages.find { |message| message.data["message_type"] == "muted" }

      expect(muted_message.data["topic_id"]).to eq(topic.id)
      expect(muted_message.data["message_type"]).to eq(described_class::MUTED_MESSAGE_TYPE)
    end

    it "should not publish any message when notification level is not muted" do
      messages = MessageBus.track_publish("/latest") { TopicTrackingState.publish_muted(topic) }
      muted_messages = messages.select { |message| message.data["message_type"] == "muted" }

      expect(muted_messages).to eq([])
    end

    it "should not publish any message when the user was not seen in the last 7 days" do
      TopicUser.find_by(topic: topic, user: post.user).update(notification_level: 0)
      post.user.update(last_seen_at: 8.days.ago)
      messages = MessageBus.track_publish("/latest") { TopicTrackingState.publish_muted(topic) }
      muted_messages = messages.select { |message| message.data["message_type"] == "muted" }
      expect(muted_messages).to eq([])
    end
  end

  describe "#publish_unmuted" do
    let(:user) { Fabricate(:user, last_seen_at: Date.today, refresh_auto_groups: true) }
    let(:second_user) { Fabricate(:user, last_seen_at: Date.today) }
    let(:third_user) { Fabricate(:user, last_seen_at: Date.today) }
    let(:post) { create_post(user: user) }

    include_examples("does not publish message for private topics", :publish_unmuted)

    it "can correctly publish unmuted" do
      Fabricate(:topic_tag, topic: topic)
      SiteSetting.mute_all_categories_by_default = true
      TopicUser.find_by(topic: topic, user: post.user).update(notification_level: 1)
      CategoryUser.create!(category: topic.category, user: second_user, notification_level: 1)
      TagUser.create!(tag: topic.tags.first, user: third_user, notification_level: 1)
      TagUser.create!(tag: topic.tags.first, user: Fabricate(:user), notification_level: 0)
      messages = MessageBus.track_publish("/latest") { TopicTrackingState.publish_unmuted(topic) }

      unmuted_message = messages.find { |message| message.data["message_type"] == "unmuted" }
      expect(unmuted_message.user_ids.sort).to eq([user.id, second_user.id, third_user.id].sort)
      expect(unmuted_message.data["topic_id"]).to eq(topic.id)
      expect(unmuted_message.data["message_type"]).to eq(described_class::UNMUTED_MESSAGE_TYPE)
    end

    it "should not publish any message when notification level is not muted" do
      SiteSetting.mute_all_categories_by_default = true
      TopicUser.find_by(topic: topic, user: post.user).update(notification_level: 0)
      messages = MessageBus.track_publish("/latest") { TopicTrackingState.publish_unmuted(topic) }
      unmuted_messages = messages.select { |message| message.data["message_type"] == "unmuted" }

      expect(unmuted_messages).to eq([])
    end

    it "should not publish any message when the user was not seen in the last 7 days" do
      TopicUser.find_by(topic: topic, user: post.user).update(notification_level: 1)
      post.user.update(last_seen_at: 8.days.ago)
      messages = MessageBus.track_publish("/latest") { TopicTrackingState.publish_unmuted(topic) }
      unmuted_messages = messages.select { |message| message.data["message_type"] == "unmuted" }
      expect(unmuted_messages).to eq([])
    end
  end

  describe "#publish_read_private_message" do
    fab!(:group)
    let(:read_topic_key) { "/private-messages/unread-indicator/#{group_message.id}" }
    let(:read_post_key) { "/topic/#{group_message.id}" }
    let(:group_message) do
      Fabricate(
        :private_message_topic,
        allowed_groups: [group],
        topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: user)],
      )
    end
    let!(:post) { Fabricate(:post, topic: group_message) }

    let!(:post_2) { Fabricate(:post, topic: group_message) }

    before do
      group.add(user)
      group_message.update!(highest_post_number: post_2.post_number)
    end

    it "does not trigger a read count update if no allowed groups have the option enabled" do
      messages =
        MessageBus.track_publish(read_post_key) do
          TopicTrackingState.publish_read_indicator_on_read(
            group_message.id,
            post_2.post_number,
            user.id,
          )
        end

      expect(messages).to be_empty
    end

    context "when the read indicator is enabled" do
      before { group.update!(publish_read_state: true) }

      it "publishes a message to hide the unread indicator" do
        message =
          MessageBus
            .track_publish(read_topic_key) do
              TopicTrackingState.publish_read_indicator_on_read(
                group_message.id,
                post_2.post_number,
                user.id,
              )
            end
            .first

        expect(message.data["topic_id"]).to eq group_message.id
        expect(message.data["show_indicator"]).to eq false
      end

      it "publishes a message to show the unread indicator when a non-member creates a new post" do
        allowed_user = Fabricate(:topic_allowed_user, topic: group_message)
        message =
          MessageBus
            .track_publish(read_topic_key) do
              TopicTrackingState.publish_read_indicator_on_write(
                group_message.id,
                post_2.post_number,
                allowed_user.id,
              )
            end
            .first

        expect(message.data["topic_id"]).to eq group_message.id
        expect(message.data["show_indicator"]).to eq true
      end

      it "does not publish the unread indicator if the message is not the last one" do
        messages =
          MessageBus.track_publish(read_topic_key) do
            TopicTrackingState.publish_read_indicator_on_read(
              group_message.id,
              post.post_number,
              user.id,
            )
          end

        expect(messages).to be_empty
      end

      it "does not publish the read indicator if the user is not a group member" do
        allowed_user = Fabricate(:topic_allowed_user, topic: group_message)
        messages =
          MessageBus.track_publish(read_topic_key) do
            TopicTrackingState.publish_read_indicator_on_read(
              group_message.id,
              post_2.post_number,
              allowed_user.user_id,
            )
          end

        expect(messages).to be_empty
      end

      it "publish a read count update to every client" do
        message =
          MessageBus
            .track_publish(read_post_key) do
              TopicTrackingState.publish_read_indicator_on_read(
                group_message.id,
                post_2.post_number,
                user.id,
              )
            end
            .first

        expect(message.data[:type]).to eq :read
      end
    end
  end

  it "correctly handles muted categories" do
    post

    report = TopicTrackingState.report(user)
    expect(report.length).to eq(1)

    CategoryUser.create!(
      user_id: user.id,
      notification_level: CategoryUser.notification_levels[:muted],
      category_id: post.topic.category_id,
    )

    create_post(topic_id: post.topic_id)

    report = TopicTrackingState.report(user)
    expect(report.length).to eq(0)

    TopicUser.create!(
      user_id: user.id,
      topic_id: post.topic_id,
      last_read_post_number: 1,
      notification_level: 3,
    )

    report = TopicTrackingState.report(user)
    expect(report.length).to eq(1)
  end

  it "correctly handles indirectly muted categories" do
    parent_category = Fabricate(:category)
    sub_category = Fabricate(:category, parent_category_id: parent_category.id)
    create_post(category: sub_category)

    report = TopicTrackingState.report(user)
    expect(report.length).to eq(1)

    CategoryUser.create!(
      user_id: user.id,
      notification_level: CategoryUser.notification_levels[:muted],
      category_id: parent_category.id,
    )

    report = TopicTrackingState.report(user)
    expect(report.length).to eq(0)

    CategoryUser.create!(
      user_id: user.id,
      notification_level: CategoryUser.notification_levels[:regular],
      category_id: sub_category.id,
    )

    report = TopicTrackingState.report(user)
    expect(report.length).to eq(1)
  end

  it "works when categories are default muted" do
    SiteSetting.mute_all_categories_by_default = true

    post

    report = TopicTrackingState.report(user)
    expect(report.length).to eq(0)

    CategoryUser.create!(
      user_id: user.id,
      notification_level: CategoryUser.notification_levels[:regular],
      category_id: post.topic.category_id,
    )

    create_post(topic_id: post.topic_id)

    report = TopicTrackingState.report(user)
    expect(report.length).to eq(1)
  end

  describe "muted tags" do
    it "remove_muted_tags_from_latest is set to always" do
      SiteSetting.remove_muted_tags_from_latest = "always"
      tag1 = Fabricate(:tag)
      tag2 = Fabricate(:tag)
      Fabricate(:topic_tag, tag: tag1, topic: topic)
      Fabricate(:topic_tag, tag: tag2, topic: topic)
      post

      report = TopicTrackingState.report(user)
      expect(report.length).to eq(1)

      TagUser.create!(
        user_id: user.id,
        notification_level: TagUser.notification_levels[:muted],
        tag_id: tag1.id,
      )

      report = TopicTrackingState.report(user)
      expect(report.length).to eq(0)

      TopicTag.where(topic_id: topic.id).delete_all

      report = TopicTrackingState.report(user)
      expect(report.length).to eq(1)
    end

    it "remove_muted_tags_from_latest is set to only_muted" do
      SiteSetting.remove_muted_tags_from_latest = "only_muted"
      tag1 = Fabricate(:tag)
      tag2 = Fabricate(:tag)
      Fabricate(:topic_tag, tag: tag1, topic: topic)
      Fabricate(:topic_tag, tag: tag2, topic: topic)
      post

      report = TopicTrackingState.report(user)
      expect(report.length).to eq(1)

      TagUser.create!(
        user_id: user.id,
        notification_level: TagUser.notification_levels[:muted],
        tag_id: tag1.id,
      )

      report = TopicTrackingState.report(user)
      expect(report.length).to eq(1)

      TagUser.create!(
        user_id: user.id,
        notification_level: TagUser.notification_levels[:muted],
        tag_id: tag2.id,
      )

      report = TopicTrackingState.report(user)
      expect(report.length).to eq(0)

      TopicTag.where(topic_id: topic.id).delete_all

      report = TopicTrackingState.report(user)
      expect(report.length).to eq(1)
    end

    it "remove_muted_tags_from_latest is set to never" do
      SiteSetting.remove_muted_tags_from_latest = "never"
      tag1 = Fabricate(:tag)
      Fabricate(:topic_tag, tag: tag1, topic: topic)
      post

      report = TopicTrackingState.report(user)
      expect(report.length).to eq(1)

      TagUser.create!(
        user_id: user.id,
        notification_level: TagUser.notification_levels[:muted],
        tag_id: tag1.id,
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
    CategoryUser.create!(
      user_id: user.id,
      notification_level: CategoryUser.notification_levels[:regular],
      category_id: post.topic.category_id,
      last_seen_at: post.topic.created_at,
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

  describe "tag support" do
    before do
      SiteSetting.tagging_enabled = true
      SiteSetting.create_tag_allowed_groups = "10"

      post.topic.notifier.watch_topic!(post.topic.user_id)

      DiscourseTagging.tag_topic_by_names(post.topic, Guardian.new(user), %w[bananas apples])
    end

    it "includes tags based on the `tagging_enabled` site setting" do
      SiteSetting.tagging_enabled = false

      report = TopicTrackingState.report(user)
      expect(report.length).to eq(1)
      row = report[0]
      expect(row.respond_to? :tags).to eq(false)

      SiteSetting.tagging_enabled = true

      report = TopicTrackingState.report(user)
      expect(report.length).to eq(1)
      row = report[0]
      expect(row.tags).to contain_exactly("apples", "bananas")
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
      SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}"
      create_post(raw: "this is a test post", topic: topic, user: post.user)

      create_post(
        raw: "this is a test post",
        topic: topic,
        post_type: Post.types[:whisper],
        user: user,
      )

      post.user.grant_admin!

      state = TopicTrackingState.report(post.user)

      expect(state.map(&:topic_id)).to contain_exactly(topic.id)
    end
  end

  describe ".report_totals" do
    fab!(:user2) { Fabricate(:user) }

    it "correctly returns new/unread totals" do
      report = TopicTrackingState.report_totals(user)
      expect(report).to eq({ new: 0, unread: 0 })

      post.topic.notifier.watch_topic!(post.topic.user_id)

      report = TopicTrackingState.report_totals(user)
      expect(report).to eq({ new: 1, unread: 0 })

      create_post(user: user, topic: post.topic)

      # when user replies, they have 0 new count
      report = TopicTrackingState.report_totals(user)
      expect(report).to eq({ new: 0, unread: 0 })

      # when we reply the poster will have an unread item
      report = TopicTrackingState.report_totals(post.user)
      expect(report).to eq({ new: 0, unread: 1 })

      create_post(user: user2, topic: post.topic)

      # when a third user replies, the original user should have an unread item
      report = TopicTrackingState.report_totals(user)
      expect(report).to eq({ new: 0, unread: 1 })

      # the post user still has one unread
      report = TopicTrackingState.report_totals(post.user)
      expect(report).to eq({ new: 0, unread: 1 })

      post2 = create_post
      post2.topic.notifier.watch_topic!(user.id)

      # watching another new topic bumps the new count
      report = TopicTrackingState.report_totals(user)
      expect(report).to eq({ new: 1, unread: 1 })
    end

    it "respects treat_as_new_topic_start_date user option" do
      report = TopicTrackingState.report_totals(user)
      expect(report).to eq({ new: 0, unread: 0 })

      post.topic.notifier.watch_topic!(post.topic.user_id)

      report = TopicTrackingState.report_totals(user)
      expect(report).to eq({ new: 1, unread: 0 })

      user.user_option.new_topic_duration_minutes = 5
      user.user_option.save
      post.topic.created_at = 10.minutes.ago
      post.topic.save

      report = TopicTrackingState.report_totals(user)
      expect(report).to eq({ new: 0, unread: 0 })
    end

    it "respects new_new_view_enabled" do
      new_new_group = Fabricate(:group)
      SiteSetting.experimental_new_new_view_groups = new_new_group.name
      user.groups << new_new_group

      report = TopicTrackingState.report_totals(user)
      expect(report).to eq({ new: 0 })

      post.topic.notifier.watch_topic!(post.topic.user_id)

      post2 = create_post
      Fabricate(:post, topic: post2.topic)

      tracking = {
        notification_level: TopicUser.notification_levels[:tracking],
        last_read_post_number: 1,
      }

      TopicUser.change(user.id, post2.topic_id, tracking)

      report = TopicTrackingState.report_totals(user)
      expect(report).to eq({ new: 2 })
    end
  end

  describe ".publish_recover" do
    include_examples("publishes message to right groups and users", "/recover", :publish_recover)
    include_examples("does not publish message for private topics", :publish_recover)
  end

  describe ".publish_delete" do
    include_examples("publishes message to right groups and users", "/delete", :publish_delete)
    include_examples("does not publish message for private topics", :publish_delete)
  end

  describe ".publish_destroy" do
    include_examples("publishes message to right groups and users", "/destroy", :publish_destroy)
    include_examples("does not publish message for private topics", :publish_destroy)
  end

  describe "#publish_dismiss_new_posts" do
    it "publishes the right message to the right users" do
      messages =
        MessageBus.track_publish(TopicTrackingState.unread_channel_key(user.id)) do
          TopicTrackingState.publish_dismiss_new_posts(user.id, topic_ids: [topic.id])
        end

      expect(messages.size).to eq(1)

      message = messages.first

      expect(message.data["payload"]["topic_ids"]).to contain_exactly(topic.id)
      expect(message.user_ids).to eq([user.id])
    end
  end
end
