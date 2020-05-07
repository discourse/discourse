# frozen_string_literal: true

require 'rails_helper'

describe Notification do
  before do
    NotificationEmailer.enable
  end

  it { is_expected.to validate_presence_of :notification_type }
  it { is_expected.to validate_presence_of :data }

  it { is_expected.to belong_to :user }
  it { is_expected.to belong_to :topic }

  describe '#types' do
    context "verify enum sequence" do
      before do
        @types = Notification.types
      end

      it "'mentioned' should be at 1st position" do
        expect(@types[:mentioned]).to eq(1)
      end

      it "'group_mentioned' should be at 15th position" do
        expect(@types[:group_mentioned]).to eq(15)
      end
    end
  end

  describe 'post' do
    let(:topic) { Fabricate(:topic) }
    let(:post_args) do
      { user: topic.user, topic: topic }
    end

    let(:coding_horror) { Fabricate(:coding_horror) }

    describe 'replies' do
      def process_alerts(post)
        PostAlerter.post_created(post)
      end

      let(:post) {
        process_alerts(Fabricate(:post, post_args.merge(raw: "Hello @CodingHorror")))
      }

      it 'notifies the poster on reply' do
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

    describe 'watching' do
      it "does notify watching users of new posts" do
        post = PostAlerter.post_created(Fabricate(:post, post_args))
        user2 = Fabricate(:coding_horror)
        post_args[:topic].notify_watch!(user2)
        expect {
          PostAlerter.post_created(Fabricate(:post, user: post.user, topic: post.topic))
        }.to change(user2.notifications, :count).by(1)
      end
    end

    describe 'muting' do
      it "does not notify users of new posts" do
        post = Fabricate(:post, post_args)
        user = post_args[:user]
        user2 = Fabricate(:coding_horror)

        post_args[:topic].notify_muted!(user)
        expect {
          Fabricate(:post, user: user2, topic: post.topic, raw: 'hello @' + user.username)
        }.to change(user.notifications, :count).by(0)
      end
    end

  end

  describe 'high priority creation' do
    fab!(:user) { Fabricate(:user) }

    it "automatically marks the notification as high priority if it is a high priority type" do
      notif = Notification.create(user: user, notification_type: Notification.types[:bookmark_reminder], data: {})
      expect(notif.high_priority).to eq(true)
      notif = Notification.create(user: user, notification_type: Notification.types[:private_message], data: {})
      expect(notif.high_priority).to eq(true)
      notif = Notification.create(user: user, notification_type: Notification.types[:liked], data: {})
      expect(notif.high_priority).to eq(false)
    end

    it "allows manually specifying a notification is high priority" do
      notif = Notification.create(user: user, notification_type: Notification.types[:liked], data: {}, high_priority: true)
      expect(notif.high_priority).to eq(true)
    end
  end

  describe 'unread counts' do

    fab!(:user) { Fabricate(:user) }

    context 'a regular notification' do
      it 'increases unread_notifications' do
        expect { Fabricate(:notification, user: user); user.reload }.to change(user, :unread_notifications)
      end

      it 'increases total_unread_notifications' do
        expect { Fabricate(:notification, user: user); user.reload }.to change(user, :total_unread_notifications)
      end

      it "doesn't increase unread_private_messages" do
        expect { Fabricate(:notification, user: user); user.reload }.not_to change(user, :unread_private_messages)
      end
    end

    context 'a private message' do
      it "doesn't increase unread_notifications" do
        expect { Fabricate(:private_message_notification, user: user); user.reload }.not_to change(user, :unread_notifications)
      end

      it 'increases total_unread_notifications' do
        expect { Fabricate(:notification, user: user); user.reload }.to change(user, :total_unread_notifications)
      end

      it "increases unread_private_messages" do
        expect { Fabricate(:private_message_notification, user: user); user.reload }.to change(user, :unread_private_messages)
      end

      it "increases unread_high_priority_notifications" do
        expect { Fabricate(:private_message_notification, user: user); user.reload }.to change(user, :unread_high_priority_notifications)
      end
    end

    context 'a bookmark reminder message' do
      it "doesn't increase unread_notifications" do
        expect { Fabricate(:bookmark_reminder_notification, user: user); user.reload }.not_to change(user, :unread_notifications)
      end

      it 'increases total_unread_notifications' do
        expect { Fabricate(:notification, user: user); user.reload }.to change(user, :total_unread_notifications)
      end

      it "increases unread_high_priority_notifications" do
        expect { Fabricate(:bookmark_reminder_notification, user: user); user.reload }.to change(user, :unread_high_priority_notifications)
      end
    end

  end

  describe 'message bus' do
    fab!(:user) { Fabricate(:user) }

    it 'updates the notification count on create' do
      Notification.any_instance.expects(:refresh_notification_count).returns(nil)
      Fabricate(:notification)
    end

    it 'works' do
      messages = MessageBus.track_publish do
        user.notifications.create!(notification_type: Notification.types[:mentioned], data: '{}')
        user.notifications.create!(notification_type: Notification.types[:mentioned], data: '{}')
      end

      expect(messages.size).to eq(2)
      expect(messages[0].channel).to eq("/notification/#{user.id}")
      expect(messages[0].data[:unread_notifications]).to eq(1)
      expect(messages[1].channel).to eq("/notification/#{user.id}")
      expect(messages[1].data[:unread_notifications]).to eq(2)
    end

    it 'works for partial model instances' do
      NotificationEmailer.disable
      partial_user = User.select(:id).find_by(id: user.id)
      partial_user.notifications.create!(notification_type: Notification.types[:mentioned], data: '{}')
    end

    context 'destroy' do
      let!(:notification) { Fabricate(:notification) }

      it 'updates the notification count on destroy' do
        Notification.any_instance.expects(:refresh_notification_count).returns(nil)
        notification.destroy!
      end

    end
  end

  describe 'private message' do
    before do
      @topic = Fabricate(:private_message_topic)
      @post = Fabricate(:post, topic: @topic, user: @topic.user)
      @target = @post.topic.topic_allowed_users.reject { |a| a.user_id == @post.user_id }[0].user

      TopicUser.change(@target.id, @topic.id, notification_level: TopicUser.notification_levels[:watching])

      PostAlerter.post_created(@post)
    end

    it 'should create and rollup private message notifications' do
      expect(@target.notifications.first.notification_type).to eq(Notification.types[:private_message])
      expect(@post.user.unread_notifications).to eq(0)
      expect(@post.user.total_unread_notifications).to eq(0)
      expect(@target.unread_private_messages).to eq(1)

      Fabricate(:post, topic: @topic, user: @topic.user)
      @target.reload
      expect(@target.unread_private_messages).to eq(1)
    end

  end

  describe '.post' do

    let(:post) { Fabricate(:post) }
    let!(:notification) { Fabricate(:notification, user: post.user, topic: post.topic, post_number: post.post_number) }

    it 'returns the post' do
      expect(notification.post).to eq(post)
    end

  end

  describe 'data' do
    let(:notification) { Fabricate.build(:notification) }

    it 'should have a data hash' do
      expect(notification.data_hash).to be_present
    end

    it 'should have the data within the json' do
      expect(notification.data_hash[:poison]).to eq('ivy')
    end
  end

  describe 'saw_regular_notification_id' do
    it 'correctly updates the read state' do
      user = Fabricate(:user)

      t = Fabricate(:topic)

      Notification.create!(read: false,
                           user_id: user.id,
                           topic_id: t.id,
                           post_number: 1,
                           data: '{}',
                           notification_type: Notification.types[:private_message])

      Notification.create!(read: false,
                           user_id: user.id,
                           topic_id: t.id,
                           post_number: 1,
                           data: '{}',
                           notification_type: Notification.types[:bookmark_reminder])

      other = Notification.create!(read: false,
                                   user_id: user.id,
                                   topic_id: t.id,
                                   post_number: 1,
                                   data: '{}',
                                   notification_type: Notification.types[:mentioned])

      user.saw_notification_id(other.id)
      user.reload

      expect(user.unread_notifications).to eq(0)
      expect(user.total_unread_notifications).to eq(3)
      # NOTE: because of deprecation this will be equal to unread_high_priority_notifications,
      #       to be remonved in 2.5
      expect(user.unread_private_messages).to eq(2)
      expect(user.unread_high_priority_notifications).to eq(2)
    end
  end

  describe 'mark_posts_read' do
    it "marks multiple posts as read if needed" do
      user = Fabricate(:user)

      (1..3).map do |i|
        Notification.create!(read: false, user_id: user.id, topic_id: 2, post_number: i, data: '{}', notification_type: 1)
      end
      Notification.create!(read: true, user_id: user.id, topic_id: 2, post_number: 4, data: '{}', notification_type: 1)

      expect { Notification.mark_posts_read(user, 2, [1, 2, 3, 4]) }.to change { Notification.where(read: true).count }.by(3)
    end
  end

  describe '#ensure_consistency!' do
    it 'deletes notifications if post is missing or deleted' do

      NotificationEmailer.disable

      p = Fabricate(:post)
      p2 = Fabricate(:post)

      Notification.create!(read: false, user_id: p.user_id, topic_id: p.topic_id, post_number: p.post_number, data: '[]',
                           notification_type: Notification.types[:private_message])
      Notification.create!(read: false, user_id: p2.user_id, topic_id: p2.topic_id, post_number: p2.post_number, data: '[]',
                           notification_type: Notification.types[:private_message])
      Notification.create!(read: false, user_id: p2.user_id, topic_id: p2.topic_id, post_number: p2.post_number, data: '[]',
                           notification_type: Notification.types[:bookmark_reminder])

      Notification.create!(read: false, user_id: p2.user_id, topic_id: p2.topic_id, post_number: p2.post_number, data: '[]',
                           notification_type: Notification.types[:liked])
      p2.trash!(p.user)

      # we may want to make notification "trashable" but for now we nuke pm notifications from deleted topics/posts
      Notification.ensure_consistency!

      expect(Notification.count).to eq(2)
    end
  end

  describe '.filter_by_consolidation_data' do
    let(:post) { Fabricate(:post) }
    fab!(:user) { Fabricate(:user) }

    before do
      PostActionNotifier.enable
    end

    it 'should return the right notifications' do
      expect(Notification.filter_by_consolidation_data(
        Notification.types[:liked], display_username: user.username_lower
      )).to eq([])

      expect do
        PostAlerter.post_created(Fabricate(:basic_reply,
          user: user,
          topic: post.topic
        ))

        PostActionCreator.like(user, post)
      end.to change { Notification.count }.by(2)

      expect(Notification.filter_by_consolidation_data(
        Notification.types[:liked], display_username: user.username_lower
      )).to contain_exactly(
        Notification.find_by(notification_type: Notification.types[:liked])
      )
    end
  end

end

# pulling this out cause I don't want an observer
describe Notification do
  describe '#recent_report' do
    fab!(:user) { Fabricate(:user) }
    let(:post) { Fabricate(:post) }

    def fab(type, read)
      @i ||= 0
      @i += 1
      Notification.create!(read: read, user_id: user.id, topic_id: post.topic_id, post_number: post.post_number, data: '[]',
                           notification_type: type, created_at: @i.days.from_now)
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

    it 'correctly finds visible notifications' do
      pm
      expect(Notification.visible.count).to eq(1)
      post.topic.trash!
      expect(Notification.visible.count).to eq(0)
    end

    it 'orders stuff by creation descending, bumping unread high priority (pms, bookmark reminders) to top' do
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

    describe 'for a user that does not want to be notify on liked' do
      before do
        user.user_option.update!(
          like_notification_frequency:
            UserOption.like_notification_frequency_type[:never]
        )
      end

      it "should not return any form of liked notifications" do
        notification = pm
        regular
        liked_consolidated

        expect(Notification.recent_report(user)).to contain_exactly(notification)
      end
    end

    describe '#consolidate_membership_requests' do
      fab!(:group) { Fabricate(:group, name: "XXsssssddd") }
      fab!(:user) { Fabricate(:user) }
      fab!(:post) { Fabricate(:post) }

      def create_membership_request_notification
        Notification.create(
          notification_type: Notification.types[:private_message],
          user_id: user.id,
          data: {
            topic_title: I18n.t('groups.request_membership_pm.title', group_name: group.name),
            original_post_id: post.id
          }.to_json,
          updated_at: Time.zone.now,
          created_at: Time.zone.now
        )
      end

      before do
        PostCustomField.create!(post_id: post.id, name: "requested_group_id", value: group.id)
        2.times { create_membership_request_notification }
      end

      it 'should consolidate membership requests to a new notification' do
        notification = create_membership_request_notification
        notification.reload

        notification = create_membership_request_notification
        expect { notification.reload }.to raise_error(ActiveRecord::RecordNotFound)

        notification = Notification.last
        expect(notification.notification_type).to eq(Notification.types[:membership_request_consolidated])

        data = notification.data_hash
        expect(data[:group_name]).to eq(group.name)
        expect(data[:count]).to eq(4)

        notification = create_membership_request_notification
        expect { notification.reload }.to raise_error(ActiveRecord::RecordNotFound)

        expect(Notification.last.data_hash[:count]).to eq(5)
      end
    end
  end

  describe "purge_old!" do
    fab!(:user) { Fabricate(:user) }
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

      expect(Notification.where(user_id: user.id).pluck(:id)).to contain_exactly(notification4.id, notification3.id)
    end
  end
end
