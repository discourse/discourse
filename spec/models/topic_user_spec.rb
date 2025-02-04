# frozen_string_literal: true

RSpec.describe TopicUser do
  let :watching do
    TopicUser.notification_levels[:watching]
  end

  let :regular do
    TopicUser.notification_levels[:regular]
  end

  let :tracking do
    TopicUser.notification_levels[:tracking]
  end

  describe "#unwatch_categories!" do
    it "correctly unwatches categories" do
      op_topic = Fabricate(:topic)
      another_topic = Fabricate(:topic)
      tracked_topic = Fabricate(:topic)

      user = op_topic.user

      TopicUser.change(user.id, op_topic, notification_level: watching)
      TopicUser.change(user.id, another_topic, notification_level: watching)
      TopicUser.change(
        user.id,
        tracked_topic,
        notification_level: watching,
        total_msecs_viewed: SiteSetting.default_other_auto_track_topics_after_msecs + 1,
      )

      TopicUser.unwatch_categories!(user, [Fabricate(:category).id, Fabricate(:category).id])
      expect(TopicUser.get(another_topic, user).notification_level).to eq(watching)

      TopicUser.unwatch_categories!(user, [op_topic.category_id])

      expect(TopicUser.get(op_topic, user).notification_level).to eq(watching)
      expect(TopicUser.get(another_topic, user).notification_level).to eq(regular)
      expect(TopicUser.get(tracked_topic, user).notification_level).to eq(tracking)
    end
  end

  describe "#notification_levels" do
    context "when verifying enum sequence" do
      before { @notification_levels = TopicUser.notification_levels }

      it "'muted' should be at 0 position" do
        expect(@notification_levels[:muted]).to eq(0)
      end

      it "'watching' should be at 3rd position" do
        expect(@notification_levels[:watching]).to eq(3)
      end
    end
  end

  describe "#notification_reasons" do
    context "when verifying enum sequence" do
      before { @notification_reasons = TopicUser.notification_reasons }

      it "'created_topic' should be at 1st position" do
        expect(@notification_reasons[:created_topic]).to eq(1)
      end

      it "'plugin_changed' should be at 9th position" do
        expect(@notification_reasons[:plugin_changed]).to eq(9)
      end
    end
  end

  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :topic }

  fab!(:user)

  let(:topic) do
    u = Fabricate(:user, refresh_auto_groups: true)
    guardian = Guardian.new(u)
    TopicCreator.create(u, guardian, title: "this is my topic title")
  end
  let(:topic_user) { TopicUser.get(topic, user) }
  let(:topic_creator_user) { TopicUser.get(topic, topic.user) }

  let(:new_user) do
    u = Fabricate(:user)
    u.user_option.update_columns(auto_track_topics_after_msecs: 1000)
    u
  end

  let(:topic_new_user) { TopicUser.get(topic, new_user) }
  let(:yesterday) { DateTime.now.yesterday }

  def ensure_topic_user
    TopicUser.change(user, topic, last_emailed_post_number: 1)
  end

  describe "unpinned" do
    it "defaults to blank" do
      ensure_topic_user
      expect(topic_user.cleared_pinned_at).to be_blank
    end
  end

  describe "notifications" do
    it "should trigger the right DiscourseEvent" do
      called = false
      blk = Proc.new { called = true }
      begin
        DiscourseEvent.on(:topic_notification_level_changed, &blk)

        TopicUser.change(
          user.id,
          topic.id,
          notification_level: TopicUser.notification_levels[:tracking],
        )

        expect(called).to eq(true)
      ensure
        DiscourseEvent.off(:topic_notification_level_changed, &blk)
      end
    end

    it "should be set to tracking if auto_track_topics is enabled" do
      user.user_option.update_column(:auto_track_topics_after_msecs, 0)
      ensure_topic_user
      expect(TopicUser.get(topic, user).notification_level).to eq(
        TopicUser.notification_levels[:tracking],
      )
    end

    it "should reset regular topics to tracking topics if auto track is changed" do
      ensure_topic_user
      user.user_option.auto_track_topics_after_msecs = 0
      user.user_option.save
      expect(topic_user.notification_level).to eq(TopicUser.notification_levels[:tracking])
    end

    it 'should be set to "regular" notifications, by default on non creators' do
      ensure_topic_user
      expect(TopicUser.get(topic, user).notification_level).to eq(
        TopicUser.notification_levels[:regular],
      )
    end

    it "reason should reset when changed" do
      topic.notify_muted!(topic.user)
      expect(TopicUser.get(topic, topic.user).notifications_reason_id).to eq(
        TopicUser.notification_reasons[:user_changed],
      )
    end

    it "should have the correct reason for a user change when watched" do
      topic.notify_watch!(user)
      expect(topic_user.notification_level).to eq(TopicUser.notification_levels[:watching])
      expect(topic_user.notifications_reason_id).to eq(
        TopicUser.notification_reasons[:user_changed],
      )
      expect(topic_user.notifications_changed_at).not_to eq(nil)
    end

    it "should have the correct reason for a user change when set to regular" do
      topic.notify_regular!(user)
      expect(topic_user.notification_level).to eq(TopicUser.notification_levels[:regular])
      expect(topic_user.notifications_reason_id).to eq(
        TopicUser.notification_reasons[:user_changed],
      )
      expect(topic_user.notifications_changed_at).not_to eq(nil)
    end

    it "should have the correct reason for a user change when set to regular" do
      topic.notify_muted!(user)
      expect(topic_user.notification_level).to eq(TopicUser.notification_levels[:muted])
      expect(topic_user.notifications_reason_id).to eq(
        TopicUser.notification_reasons[:user_changed],
      )
      expect(topic_user.notifications_changed_at).not_to eq(nil)
    end

    it "should watch topics a user created" do
      expect(topic_creator_user.notification_level).to eq(TopicUser.notification_levels[:watching])
      expect(topic_creator_user.notifications_reason_id).to eq(
        TopicUser.notification_reasons[:created_topic],
      )
    end
  end

  describe "visited at" do
    it "set upon initial visit and fires DiscourseEvent" do
      freeze_time yesterday

      event =
        DiscourseEvent
          .track_events(:user_first_visit_to_topic) { TopicUser.track_visit!(topic.id, user.id) }
          .first
      expect(event[:params].first[:user_id]).to eq(user.id)
      expect(event[:params].first[:topic_id]).to eq(topic.id)

      expect(topic_user.first_visited_at.to_i).to eq(yesterday.to_i)
      expect(topic_user.last_visited_at.to_i).to eq(yesterday.to_i)
    end

    it "updates upon repeat visit and doesn't fire DiscourseEvent" do
      freeze_time yesterday

      TopicUser.track_visit!(topic.id, user.id)

      freeze_time Time.zone.now

      events =
        DiscourseEvent.track_events(:user_first_visit_to_topic) do
          TopicUser.track_visit!(topic.id, user.id)
        end
      expect(events).to be_blank

      # reload is a no go
      topic_user = TopicUser.get(topic, user)
      expect(topic_user.first_visited_at.to_i).to eq(yesterday.to_i)
      expect(topic_user.last_visited_at.to_i).to eq(Time.zone.now.to_i)
    end
  end

  describe "read tracking" do
    context "without auto tracking" do
      let(:topic_user) { TopicUser.get(topic, user) }

      it "should create a new record for a visit" do
        freeze_time yesterday

        TopicUser.update_last_read(user, topic.id, 1, 1, 0)

        expect(topic_user.last_read_post_number).to eq(1)
        expect(topic_user.last_visited_at.to_i).to eq(yesterday.to_i)
        expect(topic_user.first_visited_at.to_i).to eq(yesterday.to_i)
      end

      it "should update the record for repeat visit" do
        today = Time.zone.now
        freeze_time today

        # ensure data model is correct for the test
        # logging an update to a row that does not exist
        # is not supported
        _post1 = Fabricate(:post, topic: topic)
        _post2 = Fabricate(:post, topic: topic)

        TopicUser.update_last_read(user, topic.id, 1, 1, 0)

        tomorrow = 1.day.from_now
        freeze_time tomorrow

        Fabricate(:post, topic: topic, user: user)
        channel = TopicTrackingState.unread_channel_key(user.id)

        messages =
          MessageBus.track_publish(channel) { TopicUser.update_last_read(user, topic.id, 2, 1, 0) }

        expect(messages.blank?).to eq(false)

        topic_user = TopicUser.get(topic, user)

        expect(topic_user.last_read_post_number).to eq(2)
        expect(topic_user.last_visited_at.to_i).to eq(today.to_i)
        expect(topic_user.first_visited_at.to_i).to eq(today.to_i)
      end
    end

    context "with private messages" do
      fab!(:target_user) { Fabricate(:user, refresh_auto_groups: true) }

      let(:post) do
        create_post(archetype: Archetype.private_message, target_usernames: target_user.username)
      end

      let(:topic) { post.topic }

      it "should ensure recipients and senders are watching" do
        expect(TopicUser.get(topic, post.user).notification_level).to eq(
          TopicUser.notification_levels[:watching],
        )

        expect(TopicUser.get(topic, target_user).notification_level).to eq(
          TopicUser.notification_levels[:watching],
        )
      end

      it "should ensure invited user is watching once visited" do
        another_user = Fabricate(:user)
        topic.invite(target_user, another_user.username)
        TopicUser.track_visit!(topic.id, another_user.id)

        expect(TopicUser.get(topic, another_user).notification_level).to eq(
          TopicUser.notification_levels[:watching],
        )

        another_user = Fabricate(:user)
        TopicUser.track_visit!(topic.id, another_user.id)

        expect(TopicUser.get(topic, another_user).notification_level).to eq(
          TopicUser.notification_levels[:regular],
        )
      end

      it "should publish the right message_bus message" do
        TopicUser.update_last_read(user, topic.id, 1, 1, 0)

        Fabricate(:post, topic: topic, user: user)

        channel = PrivateMessageTopicTrackingState.user_channel(user.id)

        messages =
          MessageBus.track_publish(channel) { TopicUser.update_last_read(user, topic.id, 2, 1, 0) }

        expect(messages.blank?).to eq(false)
      end

      describe "inviting a group" do
        let(:group) do
          Fabricate(:group, default_notification_level: NotificationLevels.topic_levels[:tracking])
        end

        it "should use group's default notification level" do
          another_user = Fabricate(:user, refresh_auto_groups: true)
          group.add(another_user)

          Jobs.run_immediately!
          topic.invite_group(target_user, group)

          expect(TopicUser.get(topic, another_user).notification_level).to eq(
            TopicUser.notification_levels[:tracking],
          )

          another_user = Fabricate(:user)
          topic.invite(target_user, another_user.username)
          TopicUser.track_visit!(topic.id, another_user.id)

          expect(TopicUser.get(topic, another_user).notification_level).to eq(
            TopicUser.notification_levels[:watching],
          )
        end
      end
    end

    context "with auto tracking" do
      let(:post_creator) do
        PostCreator.new(new_user, raw: Fabricate.build(:post).raw, topic_id: topic.id)
      end

      before { TopicUser.update_last_read(new_user, topic.id, 2, 2, 0) }

      it "should automatically track topics you reply to" do
        post_creator.create
        expect(topic_new_user.notification_level).to eq(TopicUser.notification_levels[:tracking])
        expect(topic_new_user.notifications_reason_id).to eq(
          TopicUser.notification_reasons[:created_post],
        )
      end

      it "should update tracking state when you reply" do
        new_user.user_option.update_column(:notification_level_when_replying, 3)
        post_creator.create
        DB.exec(
          "UPDATE topic_users set notification_level=2
                 WHERE topic_id = :topic_id AND user_id = :user_id",
          topic_id: topic_new_user.topic_id,
          user_id: topic_new_user.user_id,
        )

        TopicUser.auto_notification(
          topic_new_user.user_id,
          topic_new_user.topic_id,
          TopicUser.notification_reasons[:created_post],
          TopicUser.notification_levels[:watching],
        )

        tu = TopicUser.find_by(user_id: topic_new_user.user_id, topic_id: topic_new_user.topic_id)
        expect(tu.notification_level).to eq(TopicUser.notification_levels[:watching])
      end

      it "should not update tracking state when you reply" do
        new_user.user_option.update_column(:notification_level_when_replying, 3)
        post_creator.create
        DB.exec(
          "UPDATE topic_users set notification_level=3
                       WHERE topic_id = :topic_id AND user_id = :user_id",
          topic_id: topic_new_user.topic_id,
          user_id: topic_new_user.user_id,
        )
        TopicUser.auto_notification(
          topic_new_user.user_id,
          topic_new_user.topic_id,
          TopicUser.notification_reasons[:created_post],
          TopicUser.notification_levels[:tracking],
        )

        tu = TopicUser.find_by(user_id: topic_new_user.user_id, topic_id: topic_new_user.topic_id)
        expect(tu.notification_level).to eq(TopicUser.notification_levels[:watching])
      end

      it "should not update tracking state when state manually set to normal you reply" do
        new_user.user_option.update_column(:notification_level_when_replying, 3)
        post_creator.create
        DB.exec(
          "UPDATE topic_users set notification_level=1
                       WHERE topic_id = :topic_id AND user_id = :user_id",
          topic_id: topic_new_user.topic_id,
          user_id: topic_new_user.user_id,
        )
        TopicUser.auto_notification(
          topic_new_user.user_id,
          topic_new_user.topic_id,
          TopicUser.notification_reasons[:created_post],
          TopicUser.notification_levels[:tracking],
        )

        tu = TopicUser.find_by(user_id: topic_new_user.user_id, topic_id: topic_new_user.topic_id)
        expect(tu.notification_level).to eq(TopicUser.notification_levels[:regular])
      end

      it "should not update tracking state when state manually set to muted you reply" do
        new_user.user_option.update_column(:notification_level_when_replying, 3)
        post_creator.create
        DB.exec(
          "UPDATE topic_users set notification_level=0
                       WHERE topic_id = :topic_id AND user_id = :user_id",
          topic_id: topic_new_user.topic_id,
          user_id: topic_new_user.user_id,
        )
        TopicUser.auto_notification(
          topic_new_user.user_id,
          topic_new_user.topic_id,
          TopicUser.notification_reasons[:created_post],
          TopicUser.notification_levels[:tracking],
        )

        tu = TopicUser.find_by(user_id: topic_new_user.user_id, topic_id: topic_new_user.topic_id)
        expect(tu.notification_level).to eq(TopicUser.notification_levels[:muted])
      end

      it "should not automatically track topics you reply to and have set state manually" do
        post_creator.create
        TopicUser.change(
          new_user,
          topic,
          notification_level: TopicUser.notification_levels[:regular],
        )
        expect(topic_new_user.notification_level).to eq(TopicUser.notification_levels[:regular])
        expect(topic_new_user.notifications_reason_id).to eq(
          TopicUser.notification_reasons[:user_changed],
        )
      end

      it "should automatically track topics after they are read for long enough" do
        expect(topic_new_user.notification_level).to eq(TopicUser.notification_levels[:regular])
        TopicUser.update_last_read(
          new_user,
          topic.id,
          2,
          2,
          SiteSetting.default_other_auto_track_topics_after_msecs + 1,
        )
        expect(TopicUser.get(topic, new_user).notification_level).to eq(
          TopicUser.notification_levels[:tracking],
        )
      end

      it "should not automatically track topics after they are read for long enough if changed manually" do
        TopicUser.change(
          new_user,
          topic,
          notification_level: TopicUser.notification_levels[:regular],
        )
        TopicUser.update_last_read(
          new_user,
          topic,
          2,
          2,
          SiteSetting.default_other_auto_track_topics_after_msecs + 1,
        )
        expect(topic_new_user.notification_level).to eq(TopicUser.notification_levels[:regular])
      end

      it "should not automatically track PMs" do
        new_user.user_option.update!(auto_track_topics_after_msecs: 0)

        another_user = Fabricate(:user, refresh_auto_groups: true)
        pm = Fabricate(:private_message_topic, user: another_user)
        pm.invite(another_user, new_user.username)

        TopicUser.track_visit!(pm.id, new_user.id)
        TopicUser.update_last_read(new_user, pm.id, 2, 2, 1000)
        expect(TopicUser.get(pm, new_user).notification_level).to eq(
          TopicUser.notification_levels[:watching],
        )
      end
    end
  end

  describe "change a flag" do
    it "only inserts a row once, even on repeated calls" do
      topic
      user

      expect {
        TopicUser.change(user, topic.id, total_msecs_viewed: 1)
        TopicUser.change(user, topic.id, total_msecs_viewed: 2)
        TopicUser.change(user, topic.id, total_msecs_viewed: 3)
      }.to change(TopicUser, :count).by(1)
    end

    describe "after creating a row" do
      before { ensure_topic_user }

      it "has a lookup" do
        expect(TopicUser.lookup_for(user, [topic])).to be_present
      end

      it "has a key in the lookup for this forum topic" do
        expect(TopicUser.lookup_for(user, [topic]).has_key?(topic.id)).to eq(true)
      end
    end
  end

  it "can scope by tracking" do
    TopicUser.create!(
      user_id: 1,
      topic_id: 1,
      notification_level: TopicUser.notification_levels[:tracking],
    )
    TopicUser.create!(
      user_id: 2,
      topic_id: 1,
      notification_level: TopicUser.notification_levels[:watching],
    )
    TopicUser.create!(
      user_id: 3,
      topic_id: 1,
      notification_level: TopicUser.notification_levels[:regular],
    )

    expect(TopicUser.tracking(1).count).to eq(2)
    expect(TopicUser.tracking(10).count).to eq(0)
  end

  it "is able to self heal" do
    p1 = Fabricate(:post)
    p2 = Fabricate(:post, user: p1.user, topic: p1.topic, post_number: 2)
    p1.topic.notifier.watch_topic!(p1.user_id)

    DB.exec(
      "UPDATE topic_users set last_read_post_number=0
                       WHERE topic_id = :topic_id AND user_id = :user_id",
      topic_id: p1.topic_id,
      user_id: p1.user_id,
    )

    [p1, p2].each do |p|
      PostTiming.create(
        topic_id: p.topic_id,
        post_number: p.post_number,
        user_id: p.user_id,
        msecs: 100,
      )
    end

    TopicUser.ensure_consistency!

    tu = TopicUser.find_by(user_id: p1.user_id, topic_id: p1.topic_id)
    expect(tu.last_read_post_number).to eq(p2.post_number)
  end

  describe "mailing_list_mode" do
    it "will receive email notification for every topic" do
      user1 = Fabricate(:user)

      Jobs.run_immediately!
      SiteSetting.disable_mailing_list_mode = false
      SiteSetting.default_email_mailing_list_mode = true
      SiteSetting.default_email_mailing_list_mode_frequency = 1

      user2 = Fabricate(:user)
      post = create_post

      user3 = Fabricate(:user)
      create_post(topic_id: post.topic_id)

      # mails posts from earlier topics
      tu = TopicUser.find_by(user_id: user3.id, topic_id: post.topic_id)
      expect(tu.last_emailed_post_number).to eq(2)

      # mails nothing to random users
      tu = TopicUser.find_by(user_id: user1.id, topic_id: post.topic_id)
      expect(tu).to eq(nil)

      # mails other user
      tu = TopicUser.find_by(user_id: user2.id, topic_id: post.topic_id)
      expect(tu.last_emailed_post_number).to eq(2)
    end
  end

  it "correctly triggers an event on first visit" do
    begin
      tracked_user = Fabricate(:user)
      post = create_post

      called = 0
      visits = []
      user_first_visit = ->(topic_id, user_id) do
        visits << "#{topic_id}-#{user_id}"
        called += 1
      end

      DiscourseEvent.on(:topic_first_visited_by_user, &user_first_visit)

      expect(called).to eq(0)

      TopicUser.change(tracked_user, post.topic.id, total_msecs_viewed: 1)

      expect(visits).to eq(["#{post.topic.id}-#{tracked_user.id}"])
      expect(called).to eq(1)

      TopicUser.change(tracked_user, post.topic.id, total_msecs_viewed: 2)

      expect(called).to eq(1)
    ensure
      DiscourseEvent.off(:topic_first_visited_by_user, &user_first_visit)
    end
  end
end
