# frozen_string_literal: true

RSpec.describe Notification do
  fab!(:user)
  fab!(:coding_horror)

  before { NotificationEmailer.enable }

  it { is_expected.to validate_presence_of :notification_type }
  it { is_expected.to validate_presence_of :data }

  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :topic }

  describe "#types" do
    context "when verifying enum sequence" do
      before { @types = Notification.types }

      it "has a correct position for each type" do
        expect(@types[:mentioned]).to eq(1)
        expect(@types[:replied]).to eq(2)
        expect(@types[:quoted]).to eq(3)
        expect(@types[:edited]).to eq(4)
        expect(@types[:liked]).to eq(5)
        expect(@types[:private_message]).to eq(6)
        expect(@types[:invited_to_private_message]).to eq(7)
        expect(@types[:invitee_accepted]).to eq(8)
        expect(@types[:posted]).to eq(9)
        expect(@types[:moved_post]).to eq(10)
        expect(@types[:linked]).to eq(11)
        expect(@types[:granted_badge]).to eq(12)
        expect(@types[:invited_to_topic]).to eq(13)
        expect(@types[:custom]).to eq(14)
        expect(@types[:group_mentioned]).to eq(15)
        expect(@types[:group_message_summary]).to eq(16)
        expect(@types[:watching_first_post]).to eq(17)
        expect(@types[:topic_reminder]).to eq(18)
        expect(@types[:liked_consolidated]).to eq(19)
        expect(@types[:post_approved]).to eq(20)
        expect(@types[:code_review_commit_approved]).to eq(21)
        expect(@types[:membership_request_accepted]).to eq(22)
        expect(@types[:membership_request_consolidated]).to eq(23)
        expect(@types[:bookmark_reminder]).to eq(24)
        expect(@types[:reaction]).to eq(25)
        expect(@types[:votes_released]).to eq(26)
        expect(@types[:event_reminder]).to eq(27)
        expect(@types[:event_invitation]).to eq(28)
        expect(@types[:chat_mention]).to eq(29)
        expect(@types[:chat_message]).to eq(30)
        expect(@types[:assigned]).to eq(34)
      end
    end
  end

  describe "post" do
    let(:topic) { Fabricate(:topic) }
    let(:post_args) { { user: topic.user, topic: topic } }

    describe "replies" do
      def process_alerts(post)
        PostAlerter.post_created(post)
      end

      let(:post) { process_alerts(Fabricate(:post, post_args.merge(raw: "Hello @CodingHorror"))) }

      it "notifies the poster on reply" do
        expect {
          reply = Fabricate(:basic_reply, user: coding_horror, topic: post.topic)
          process_alerts(reply)
        }.to change(post.user.notifications, :count).by(1)
      end

      it "doesn't notify the poster when they reply to their own post" do
        expect {
          reply = Fabricate(:basic_reply, user: post.user, topic: post.topic)
          process_alerts(reply)
        }.not_to change(post.user.notifications, :count)
      end
    end

    describe "watching" do
      it "does notify watching users of new posts" do
        post = PostAlerter.post_created(Fabricate(:post, post_args))
        user2 = coding_horror
        post_args[:topic].notify_watch!(user2)
        expect {
          PostAlerter.post_created(Fabricate(:post, user: post.user, topic: post.topic))
        }.to change(user2.notifications, :count).by(1)
      end
    end

    describe "muting" do
      it "does not notify users of new posts" do
        post = Fabricate(:post, post_args)
        user = post_args[:user]
        user2 = coding_horror

        post_args[:topic].notify_muted!(user)
        expect {
          Fabricate(:post, user: user2, topic: post.topic, raw: "hello @" + user.username)
        }.not_to change(user.notifications, :count)
      end
    end
  end

  describe "high priority creation" do
    fab!(:user)

    it "automatically marks the notification as high priority if it is a high priority type" do
      notif =
        Notification.create(
          user: user,
          notification_type: Notification.types[:bookmark_reminder],
          data: {
          },
        )
      expect(notif.high_priority).to eq(true)
      notif =
        Notification.create(
          user: user,
          notification_type: Notification.types[:private_message],
          data: {
          },
        )
      expect(notif.high_priority).to eq(true)
      notif =
        Notification.create(user: user, notification_type: Notification.types[:liked], data: {})
      expect(notif.high_priority).to eq(false)
    end

    it "allows manually specifying a notification is high priority" do
      notif =
        Notification.create(
          user: user,
          notification_type: Notification.types[:liked],
          data: {
          },
          high_priority: true,
        )
      expect(notif.high_priority).to eq(true)
    end
  end

  describe "unread counts" do
    fab!(:user)

    context "with a regular notification" do
      it "increases unread_notifications" do
        expect {
          Fabricate(:notification, user: user)
          user.reload
        }.to change(user, :unread_notifications)
      end

      it "increases total_unread_notifications" do
        expect {
          Fabricate(:notification, user: user)
          user.reload
        }.to change(user, :total_unread_notifications)
      end

      it "doesn't increase unread_high_priority_notifications" do
        expect {
          Fabricate(:notification, user: user)
          user.reload
        }.not_to change(user, :unread_high_priority_notifications)
      end
    end

    context "with a private message" do
      it "doesn't increase unread_notifications" do
        expect {
          Fabricate(:private_message_notification, user: user)
          user.reload
        }.not_to change(user, :unread_notifications)
      end

      it "increases total_unread_notifications" do
        expect {
          Fabricate(:notification, user: user)
          user.reload
        }.to change(user, :total_unread_notifications)
      end

      it "increases unread_high_priority_notifications" do
        expect {
          Fabricate(:private_message_notification, user: user)
          user.reload
        }.to change(user, :unread_high_priority_notifications)
      end
    end

    context "with a bookmark reminder message" do
      it "doesn't increase unread_notifications" do
        expect {
          Fabricate(:bookmark_reminder_notification, user: user)
          user.reload
        }.not_to change(user, :unread_notifications)
      end

      it "increases total_unread_notifications" do
        expect {
          Fabricate(:notification, user: user)
          user.reload
        }.to change(user, :total_unread_notifications)
      end

      it "increases unread_high_priority_notifications" do
        expect {
          Fabricate(:bookmark_reminder_notification, user: user)
          user.reload
        }.to change(user, :unread_high_priority_notifications)
      end
    end
  end

  describe "message bus" do
    fab!(:user) { Fabricate(:user, last_seen_at: 1.day.ago) }

    it "updates the notification count on create" do
      Notification.any_instance.expects(:refresh_notification_count).returns(nil)
      Fabricate(:notification)
    end

    it "works" do
      messages =
        MessageBus.track_publish do
          user.notifications.create!(notification_type: Notification.types[:mentioned], data: "{}")
          user.notifications.create!(notification_type: Notification.types[:mentioned], data: "{}")
        end

      expect(messages.size).to eq(2)
      expect(messages[0].channel).to eq("/notification/#{user.id}")
      expect(messages[0].data[:unread_notifications]).to eq(1)
      expect(messages[1].channel).to eq("/notification/#{user.id}")
      expect(messages[1].data[:unread_notifications]).to eq(2)
    end

    it "works for partial model instances" do
      NotificationEmailer.disable
      partial_user = User.select(:id).find_by(id: user.id)
      partial_user.notifications.create!(
        notification_type: Notification.types[:mentioned],
        data: "{}",
      )
    end

    context "when destroying" do
      let!(:notification) { Fabricate(:notification) }

      it "updates the notification count on destroy" do
        Notification.any_instance.expects(:refresh_notification_count).returns(nil)
        notification.destroy!
      end
    end
  end

  describe "private message" do
    before do
      @topic = Fabricate(:private_message_topic)
      @post = Fabricate(:post, topic: @topic, user: @topic.user)
      @target = @post.topic.topic_allowed_users.reject { |a| a.user_id == @post.user_id }[0].user

      TopicUser.change(
        @target.id,
        @topic.id,
        notification_level: TopicUser.notification_levels[:watching],
      )

      PostAlerter.post_created(@post)
    end

    it "should create and roll up private message notifications" do
      expect(@target.notifications.first.notification_type).to eq(
        Notification.types[:private_message],
      )
      expect(@post.user.unread_notifications).to eq(0)
      expect(@post.user.total_unread_notifications).to eq(0)
      expect(@target.unread_high_priority_notifications).to eq(1)

      Fabricate(:post, topic: @topic, user: @topic.user)
      @target.reload
      expect(@target.unread_high_priority_notifications).to eq(1)
    end
  end

  describe ".post" do
    let(:post) { Fabricate(:post) }
    let!(:notification) do
      Fabricate(:notification, user: post.user, topic: post.topic, post_number: post.post_number)
    end

    it "returns the post" do
      expect(notification.post).to eq(post)
    end
  end

  describe "data" do
    let(:notification) { Fabricate.build(:notification) }

    it "should have a data hash" do
      expect(notification.data_hash).to be_present
    end

    it "should have the data within the json" do
      expect(notification.data_hash[:poison]).to eq("ivy")
    end
  end

  describe "saw_regular_notification_id" do
    it "correctly updates the read state" do
      t = Fabricate(:topic)

      Notification.create!(
        read: false,
        user_id: user.id,
        topic_id: t.id,
        post_number: 1,
        data: "{}",
        notification_type: Notification.types[:private_message],
      )

      Notification.create!(
        read: false,
        user_id: user.id,
        topic_id: t.id,
        post_number: 1,
        data: "{}",
        notification_type: Notification.types[:bookmark_reminder],
      )

      other =
        Notification.create!(
          read: false,
          user_id: user.id,
          topic_id: t.id,
          post_number: 1,
          data: "{}",
          notification_type: Notification.types[:mentioned],
        )

      user.bump_last_seen_notification!
      user.reload

      expect(user.unread_notifications).to eq(0)
      expect(user.total_unread_notifications).to eq(3)
      expect(user.unread_high_priority_notifications).to eq(2)
    end
  end

  describe "mark_posts_read" do
    it "marks multiple posts as read if needed" do
      (1..3).map do |i|
        Notification.create!(
          read: false,
          user_id: user.id,
          topic_id: 2,
          post_number: i,
          data: "{}",
          notification_type: 1,
        )
      end
      Notification.create!(
        read: true,
        user_id: user.id,
        topic_id: 2,
        post_number: 4,
        data: "{}",
        notification_type: 1,
      )

      expect { Notification.mark_posts_read(user, 2, [1, 2, 3, 4]) }.to change {
        Notification.where(read: true).count
      }.by(3)
    end
  end

  describe "#ensure_consistency!" do
    it "deletes notifications if post is missing or deleted" do
      NotificationEmailer.disable

      p = Fabricate(:post)
      p2 = Fabricate(:post)

      Notification.create!(
        read: false,
        user_id: p.user_id,
        topic_id: p.topic_id,
        post_number: p.post_number,
        data: "[]",
        notification_type: Notification.types[:private_message],
      )
      Notification.create!(
        read: false,
        user_id: p2.user_id,
        topic_id: p2.topic_id,
        post_number: p2.post_number,
        data: "[]",
        notification_type: Notification.types[:private_message],
      )
      Notification.create!(
        read: false,
        user_id: p2.user_id,
        topic_id: p2.topic_id,
        post_number: p2.post_number,
        data: "[]",
        notification_type: Notification.types[:bookmark_reminder],
      )

      Notification.create!(
        read: false,
        user_id: p2.user_id,
        topic_id: p2.topic_id,
        post_number: p2.post_number,
        data: "[]",
        notification_type: Notification.types[:liked],
      )
      p2.trash!(p.user)

      # we may want to make notification "trashable" but for now we nuke pm notifications from deleted topics/posts
      Notification.ensure_consistency!

      expect(Notification.count).to eq(2)
    end

    it "does not delete notifications that do not have a topic_id" do
      Notification.create!(
        read: false,
        user_id: user.id,
        topic_id: nil,
        post_number: nil,
        data: "[]",
        notification_type: Notification.types[:chat_mention],
        high_priority: true,
      )
      expect { Notification.ensure_consistency! }.to_not change { Notification.count }
    end
  end

  describe "do not disturb" do
    it "calls NotificationEmailer.process_notification when user is not in 'do not disturb'" do
      notification =
        Notification.new(
          read: false,
          user_id: user.id,
          topic_id: 2,
          post_number: 1,
          data: "{}",
          notification_type: 1,
        )
      NotificationEmailer.expects(:process_notification).with(notification)
      notification.save!
    end

    it "doesn't call NotificationEmailer.process_notification when user is in 'do not disturb'" do
      freeze_time
      Fabricate(
        :do_not_disturb_timing,
        user: user,
        starts_at: Time.zone.now,
        ends_at: 1.day.from_now,
      )

      notification =
        Notification.new(
          read: false,
          user_id: user.id,
          topic_id: 2,
          post_number: 1,
          data: "{}",
          notification_type: 1,
        )
      NotificationEmailer.expects(:process_notification).with(notification).never
      notification.save!
    end
  end
end

# pulling this out cause I don't want an observer
RSpec.describe Notification do
  fab!(:user)

  describe ".prioritized_list" do
    def create(**opts)
      opts[:user] = user if !opts[:user]
      Fabricate(:notification, user: user, **opts)
    end

    fab!(:unread_high_priority_1) do
      create(high_priority: true, read: false, created_at: 8.minutes.ago)
    end
    fab!(:read_high_priority_1) do
      create(high_priority: true, read: true, created_at: 7.minutes.ago)
    end
    fab!(:unread_regular_1) { create(high_priority: false, read: false, created_at: 6.minutes.ago) }
    fab!(:read_regular_1) { create(high_priority: false, read: true, created_at: 5.minutes.ago) }
    fab!(:unread_like) do
      create(
        high_priority: false,
        read: false,
        created_at: 130.seconds.ago,
        notification_type: Notification.types[:liked],
      )
    end

    fab!(:unread_high_priority_2) do
      create(high_priority: true, read: false, created_at: 1.minutes.ago)
    end
    fab!(:read_high_priority_2) do
      create(high_priority: true, read: true, created_at: 2.minutes.ago)
    end
    fab!(:unread_regular_2) { create(high_priority: false, read: false, created_at: 3.minutes.ago) }
    fab!(:read_regular_2) { create(high_priority: false, read: true, created_at: 4.minutes.ago) }

    it "puts unread high_priority on top followed by unread normal notifications and then everything else in reverse chronological order" do
      expect(Notification.prioritized_list(user).map(&:id)).to eq(
        [
          unread_high_priority_2,
          unread_high_priority_1,
          unread_regular_2,
          unread_regular_1,
          read_high_priority_2,
          unread_like,
          read_regular_2,
          read_regular_1,
          read_high_priority_1,
        ].map(&:id),
      )
    end

    it "doesn't include notifications from other users" do
      another_user_notification = create(high_priority: true, read: false, user: Fabricate(:user))
      expect(Notification.prioritized_list(user).map(&:id)).to contain_exactly(
        *[
          unread_high_priority_2,
          unread_high_priority_1,
          unread_regular_2,
          unread_regular_1,
          read_high_priority_2,
          unread_like,
          read_regular_2,
          read_regular_1,
          read_high_priority_1,
        ].map(&:id),
      )
      expect(
        Notification.prioritized_list(another_user_notification.user).map(&:id),
      ).to contain_exactly(another_user_notification.id)
    end

    it "doesn't include notifications from deleted topics" do
      unread_high_priority_1.topic.trash!
      unread_regular_2.topic.trash!
      read_regular_1.topic.trash!
      expect(Notification.prioritized_list(user).map(&:id)).to contain_exactly(
        *[
          unread_high_priority_2,
          unread_regular_1,
          read_high_priority_2,
          unread_like,
          read_regular_2,
          read_high_priority_1,
        ].map(&:id),
      )
    end

    it "doesn't include like notifications if the user doesn't want like notifications" do
      user.user_option.update!(
        like_notification_frequency: UserOption.like_notification_frequency_type[:never],
      )
      unread_regular_1.update!(notification_type: Notification.types[:liked])
      read_regular_2.update!(notification_type: Notification.types[:liked_consolidated])
      expect(Notification.prioritized_list(user).map(&:id)).to eq(
        [
          unread_high_priority_2,
          unread_high_priority_1,
          unread_regular_2,
          read_high_priority_2,
          read_regular_1,
          read_high_priority_1,
        ].map(&:id),
      )
    end

    it "respects the count param" do
      expect(Notification.prioritized_list(user, count: 1).map(&:id)).to eq(
        [unread_high_priority_2].map(&:id),
      )

      expect(Notification.prioritized_list(user, count: 3).map(&:id)).to eq(
        [unread_high_priority_2, unread_high_priority_1, unread_regular_2].map(&:id),
      )
    end

    it "can filter the list by specific types" do
      unread_regular_1.update!(notification_type: Notification.types[:liked])
      read_regular_2.update!(notification_type: Notification.types[:liked_consolidated])
      expect(
        Notification.prioritized_list(
          user,
          types: [Notification.types[:liked], Notification.types[:liked_consolidated]],
        ).map(&:id),
      ).to eq([unread_like, unread_regular_1, read_regular_2].map(&:id))
    end

    it "includes like notifications when filtering by like types even if the user doesn't want like notifications" do
      user.user_option.update!(
        like_notification_frequency: UserOption.like_notification_frequency_type[:never],
      )
      unread_regular_1.update!(notification_type: Notification.types[:liked])
      read_regular_2.update!(notification_type: Notification.types[:liked_consolidated])
      expect(
        Notification.prioritized_list(
          user,
          types: [Notification.types[:liked], Notification.types[:liked_consolidated]],
        ).map(&:id),
      ).to eq([unread_like, unread_regular_1, read_regular_2].map(&:id))
      expect(
        Notification.prioritized_list(user, types: [Notification.types[:liked]]).map(&:id),
      ).to contain_exactly(unread_like.id, unread_regular_1.id)
    end
  end

  describe "#recent_report" do
    let(:post) { Fabricate(:post) }

    def fab(type, read)
      @i ||= 0
      @i += 1
      Notification.create!(
        read: read,
        user_id: user.id,
        topic_id: post.topic_id,
        post_number: post.post_number,
        data: "[]",
        notification_type: type,
        created_at: @i.days.from_now,
      )
    end

    def unread_pm
      fab(Notification.types[:private_message], false)
    end

    def unread_bookmark_reminder
      fab(Notification.types[:bookmark_reminder], false)
    end

    def pm
      fab(Notification.types[:private_message], true)
    end

    def regular
      fab(Notification.types[:liked], true)
    end

    def liked_consolidated
      fab(Notification.types[:liked_consolidated], true)
    end

    it "correctly finds visible notifications" do
      pm
      expect(Notification.visible.count).to eq(1)
      post.topic.trash!
      expect(Notification.visible.count).to eq(0)
    end

    it "orders stuff by creation descending, bumping unread high priority (pms, bookmark reminders) to top" do
      # note we expect the final order to read bottom-up for this list of variables,
      # with unread pm + bookmark reminder at the top of that list
      a = unread_pm
      regular
      b = unread_bookmark_reminder
      c = pm
      d = regular

      notifications = Notification.recent_report(user, 4)
      expect(notifications.map { |n| n.id }).to eq([b.id, a.id, d.id, c.id])
    end

    describe "for a user that does not want to be notify on liked" do
      before do
        user.user_option.update!(
          like_notification_frequency: UserOption.like_notification_frequency_type[:never],
        )
      end

      it "should not return any form of liked notifications" do
        notification = pm
        regular
        liked_consolidated

        expect(Notification.recent_report(user)).to contain_exactly(notification)
      end
    end

    describe "#consolidate_membership_requests" do
      fab!(:group) { Fabricate(:group, name: "XXsssssddd") }
      fab!(:user)
      fab!(:post)

      def create_membership_request_notification
        Notification.consolidate_or_create!(
          notification_type: Notification.types[:private_message],
          user_id: user.id,
          data: {
            topic_title: I18n.t("groups.request_membership_pm.title", group_name: group.name),
            original_post_id: post.id,
          }.to_json,
          updated_at: Time.zone.now,
          created_at: Time.zone.now,
        )
      end

      before do
        PostCustomField.create!(post_id: post.id, name: "requested_group_id", value: group.id)
        2.times { create_membership_request_notification }
      end

      it "should consolidate membership requests to a new notification" do
        original_notification = create_membership_request_notification
        starting_count = SiteSetting.notification_consolidation_threshold

        consolidated_notification = create_membership_request_notification
        expect { original_notification.reload }.to raise_error(ActiveRecord::RecordNotFound)

        expect(consolidated_notification.notification_type).to eq(
          Notification.types[:membership_request_consolidated],
        )

        data = consolidated_notification.data_hash
        expect(data[:group_name]).to eq(group.name)
        expect(data[:count]).to eq(starting_count + 1)

        updated_consolidated_notification = create_membership_request_notification

        expect(updated_consolidated_notification.data_hash[:count]).to eq(starting_count + 2)
      end

      it 'consolidates membership requests with "processed" false if user is in DND' do
        user.do_not_disturb_timings.create(starts_at: Time.now, ends_at: 3.days.from_now)

        create_membership_request_notification
        create_membership_request_notification

        notification = Notification.last
        expect(notification.notification_type).to eq(
          Notification.types[:membership_request_consolidated],
        )
        expect(notification.shelved_notification).to be_present
      end
    end
  end

  describe "purge_old!" do
    fab!(:user)
    fab!(:notification1) { Fabricate(:notification, user: user) }
    fab!(:notification2) { Fabricate(:notification, user: user) }
    fab!(:notification3) { Fabricate(:notification, user: user) }
    fab!(:notification4) { Fabricate(:notification, user: user) }

    it "does nothing if set to 0" do
      SiteSetting.max_notifications_per_user = 0
      Notification.purge_old!

      expect(Notification.where(user_id: user.id).count).to eq(4)
    end

    it "correctly limits" do
      SiteSetting.max_notifications_per_user = 2
      Notification.purge_old!

      expect(Notification.where(user_id: user.id).pluck(:id)).to contain_exactly(
        notification4.id,
        notification3.id,
      )
    end
  end

  describe "do not disturb" do
    fab!(:user)

    it "creates a shelved_notification record when created while user is in DND" do
      user.do_not_disturb_timings.create(starts_at: Time.now, ends_at: 3.days.from_now)
      notification =
        Notification.create(
          read: false,
          user_id: user.id,
          topic_id: 2,
          post_number: 1,
          data: "{}",
          notification_type: 1,
        )
      expect(notification.shelved_notification).to be_present
    end

    it "doesn't create a shelved_notification record when created while user is isn't DND" do
      notification =
        Notification.create(
          read: false,
          user_id: user.id,
          topic_id: 2,
          post_number: 1,
          data: "{}",
          notification_type: 1,
        )
      expect(notification.shelved_notification).to be_nil
    end
  end

  describe ".populate_acting_user" do
    SiteSetting.enable_names = true

    fab!(:user1) { Fabricate(:user) }
    fab!(:user2) { Fabricate(:user) }
    fab!(:user3) { Fabricate(:user) }
    fab!(:user4) { Fabricate(:user) }
    fab!(:user5) { Fabricate(:user) }
    fab!(:user6) { Fabricate(:user) }
    fab!(:notification1) do
      Fabricate(:notification, user: user, data: { username: user1.username }.to_json)
    end
    fab!(:notification2) do
      Fabricate(:notification, user: user, data: { display_username: user2.username }.to_json)
    end
    fab!(:notification3) do
      Fabricate(:notification, user: user, data: { mentioned_by_username: user3.username }.to_json)
    end
    fab!(:notification4) do
      Fabricate(:notification, user: user, data: { invited_by_username: user4.username }.to_json)
    end
    fab!(:notification5) do
      Fabricate(:notification, user: user, data: { original_username: user5.username }.to_json)
    end
    fab!(:notification6) do
      Fabricate(:notification, user: user, data: { original_username: user6.username }.to_json)
    end

    it "Sets the acting_user correctly for each notification" do
      # TODO: remove this spec
      expect(notification1.acting_user).to eq(user1)
      expect(notification2.acting_user).to eq(user2)
      expect(notification3.acting_user).to eq(user3)
      expect(notification4.acting_user).to eq(user4)
      expect(notification5.acting_user).to eq(user5)
      expect(notification5.data_hash[:original_name]).to eq user5.name
    end

    context "with SiteSettings.enable_names=false" do
      it "doesn't set the :original_name property" do
        SiteSetting.enable_names = false
        # todo: refactor spec
        expect(notification6.data_hash[:original_name]).to be_nil
        SiteSetting.enable_names = true
      end
    end
  end
end
