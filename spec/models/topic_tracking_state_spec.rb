require 'rails_helper'

describe TopicTrackingState do

  let(:user) do
    Fabricate(:user)
  end

  let(:post) do
    create_post
  end

  let(:topic) { post.topic }
  let(:private_message_post) { Fabricate(:private_message_post) }
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

  describe '#publish_unread' do
    it "can correctly publish unread" do
      message = MessageBus.track_publish(described_class.unread_channel_key(post.user.id)) do
        TopicTrackingState.publish_unread(post)
      end.first

      data = message.data

      expect(data["topic_id"]).to eq(topic.id)
      expect(data["message_type"]).to eq(described_class::UNREAD_MESSAGE_TYPE)
      expect(data["payload"]["archetype"]).to eq(Archetype.default)
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

  describe '#publish_private_message' do
    let!(:admin) { Fabricate(:admin) }

    describe 'normal topic' do
      it 'should publish the right message' do
        allowed_users = private_message_topic.allowed_users

        messages = MessageBus.track_publish do
          TopicTrackingState.publish_private_message(private_message_topic)
        end

        expect(messages.count).to eq(1)

        message = messages.first

        expect(message.channel).to eq('/private-messages/inbox')
        expect(message.data["topic_id"]).to eq(private_message_topic.id)
        expect(message.user_ids).to eq(allowed_users.map(&:id))
      end
    end

    describe 'topic with groups' do
      let(:group1) { Fabricate(:group, users: [Fabricate(:user)]) }
      let(:group2) { Fabricate(:group, users: [Fabricate(:user), Fabricate(:user)]) }

      before do
        [group1, group2].each do |group|
          private_message_topic.allowed_groups << group
        end
      end

      it "should publish the right message" do
        messages = MessageBus.track_publish do
          TopicTrackingState.publish_private_message(
            private_message_topic
          )
        end

        expect(messages.map(&:channel)).to contain_exactly(
          '/private-messages/inbox',
          "/private-messages/group/#{group1.name}",
          "/private-messages/group/#{group2.name}"
        )

        message = messages.find do |message|
          message.channel == '/private-messages/inbox'
        end

        expect(message.data["topic_id"]).to eq(private_message_topic.id)
        expect(message.user_ids).to eq(private_message_topic.allowed_users.map(&:id))

        [group1, group2].each do |group|
          message = messages.find do |message|
            message.channel == "/private-messages/group/#{group.name}"
          end

          expect(message.data["topic_id"]).to eq(private_message_topic.id)
          expect(message.user_ids).to eq(group.users.map(&:id))
        end
      end

      describe "archiving topic" do
        it "should publish the right message" do
          messages = MessageBus.track_publish do
            TopicTrackingState.publish_private_message(
              private_message_topic,
              group_archive: true
            )
          end

          expect(messages.map(&:channel)).to contain_exactly(
            '/private-messages/inbox',
            "/private-messages/group/#{group1.name}",
            "/private-messages/group/#{group1.name}/archive",
            "/private-messages/group/#{group2.name}",
            "/private-messages/group/#{group2.name}/archive",
          )

          message = messages.find do |message|
            message.channel == '/private-messages/inbox'
          end

          expect(message.data["topic_id"]).to eq(private_message_topic.id)
          expect(message.user_ids).to eq(private_message_topic.allowed_users.map(&:id))

          [group1, group2].each do |group|
            group_channel = "/private-messages/group/#{group.name}"

            [
              group_channel,
              "#{group_channel}/archive"
            ].each do |channel|
              message = messages.find do |message|
                message.channel == channel
              end

              expect(message.data["topic_id"]).to eq(private_message_topic.id)
              expect(message.user_ids).to eq(group.users.map(&:id))
            end
          end
        end
      end
    end

    describe 'topic with new post' do
      let(:user) { private_message_topic.allowed_users.last }

      let!(:post) do
        Fabricate(:post,
          topic: private_message_topic,
          user: user
        )
      end

      let!(:group) do
        group = Fabricate(:group, users: [Fabricate(:user)])
        private_message_topic.allowed_groups << group
        group
      end

      it 'should publish the right message' do
        messages = MessageBus.track_publish do
          TopicTrackingState.publish_private_message(
            private_message_topic,
            post: post
          )
        end

        expected_channels = [
          '/private-messages/inbox',
          '/private-messages/sent',
          "/private-messages/group/#{group.name}"
        ]

        expect(messages.map(&:channel)).to contain_exactly(*expected_channels)

        expected_channels.zip([
          private_message_topic.allowed_users.map(&:id),
          [user.id],
          [group.users.first.id]
        ]).each do |channel, user_ids|
          message = messages.find do |message|
            message.channel == channel
          end

          expect(message.data["topic_id"]).to eq(private_message_topic.id)
          expect(message.user_ids).to eq(user_ids)
        end
      end
    end

    describe 'archived topic' do
      it 'should publish the right message' do
        messages = MessageBus.track_publish do
          TopicTrackingState.publish_private_message(
            private_message_topic,
            archive_user_id: private_message_post.user_id,
          )
        end

        expected_channels = [
          "/private-messages/archive",
          "/private-messages/inbox",
          "/private-messages/sent",
        ]

        expect(messages.map(&:channel)).to eq(expected_channels)

        expected_channels.each do |channel|
          message = messages.find do |message|
            message.channel = channel
          end

          expect(message.data["topic_id"]).to eq(private_message_topic.id)
          expect(message.user_ids).to eq([private_message_post.user_id])
        end
      end
    end

    describe 'for a regular topic' do
      it 'should not publish any message' do
        topic.allowed_users << Fabricate(:user)

        messages = MessageBus.track_publish do
          TopicTrackingState.publish_private_message(topic)
        end

        expect(messages).to eq([])
      end
    end
  end

  it "correctly handles muted categories" do

    user = Fabricate(:user)
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

  it "correctly handles capping" do
    user = Fabricate(:user)

    post1 = create_post
    Fabricate(:post, topic: post1.topic)

    post2 = create_post
    Fabricate(:post, topic: post2.topic)

    post3 = create_post
    Fabricate(:post, topic: post3.topic)

    tracking = {
      notification_level: TopicUser.notification_levels[:tracking],
      last_read_post_number: 1,
      highest_seen_post_number: 1
    }

    TopicUser.change(user.id, post1.topic_id, tracking)
    TopicUser.change(user.id, post2.topic_id, tracking)
    TopicUser.change(user.id, post3.topic_id, tracking)

    report = TopicTrackingState.report(user)
    expect(report.length).to eq(3)

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
end
