require 'rails_helper'

describe Notification do
  before do
    ActiveRecord::Base.observers.enable :all
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
      {user: topic.user, topic: topic}
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

  describe 'unread counts' do

    let(:user) { Fabricate(:user) }

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
    end

  end

  describe 'message bus' do

    it 'updates the notification count on create' do
      Notification.any_instance.expects(:refresh_notification_count).returns(nil)
      Fabricate(:notification)
    end

    context 'destroy' do

      let!(:notification) { Fabricate(:notification) }

      it 'updates the notification count on destroy' do
        Notification.any_instance.expects(:refresh_notification_count).returns(nil)
        notification.destroy
      end

    end
  end

  describe '@mention' do

    it "calls email_user_mentioned on creating a notification" do
      UserEmailObserver.any_instance.expects(:after_commit).with(instance_of(Notification))
      Fabricate(:notification)
    end

  end

  describe '@mention' do
    it "calls email_user_quoted on creating a quote notification" do
      UserEmailObserver.any_instance.expects(:after_commit).with(instance_of(Notification))
      Fabricate(:quote_notification)
    end
  end

  describe 'private message' do
    before do
      @topic = Fabricate(:private_message_topic)
      @post = Fabricate(:post, topic: @topic, user: @topic.user)
      @target = @post.topic.topic_allowed_users.reject{|a| a.user_id == @post.user_id}[0].user

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

      other = Notification.create!(read: false,
                           user_id: user.id,
                           topic_id: t.id,
                           post_number: 1,
                           data: '{}',
                           notification_type: Notification.types[:mentioned])


      user.saw_notification_id(other.id)
      user.reload

      expect(user.unread_notifications).to eq(0)
      expect(user.total_unread_notifications).to eq(2)
      expect(user.unread_private_messages).to eq(1)
    end
  end

  describe 'mark_posts_read' do
    it "marks multiple posts as read if needed" do
      user = Fabricate(:user)

      (1..3).map do |i|
        Notification.create!(read: false, user_id: user.id, topic_id: 2, post_number: i, data: '{}', notification_type: 1)
      end
      Notification.create!(read: true, user_id: user.id, topic_id: 2, post_number: 4, data: '{}', notification_type: 1)

      expect { Notification.mark_posts_read(user,2,[1,2,3,4]) }.to change { Notification.where(read: true).count }.by(3)
    end
  end


  describe 'ensure consistency' do
    it 'deletes notifications if post is missing or deleted' do

      ActiveRecord::Base.observers.disable :all
      p = Fabricate(:post)
      p2 = Fabricate(:post)

      Notification.create!(read: false, user_id: p.user_id, topic_id: p.topic_id, post_number: p.post_number, data: '[]',
                           notification_type: Notification.types[:private_message])
      Notification.create!(read: false, user_id: p2.user_id, topic_id: p2.topic_id, post_number: p2.post_number, data: '[]',
                           notification_type: Notification.types[:private_message])

      Notification.create!(read: false, user_id: p2.user_id, topic_id: p2.topic_id, post_number: p2.post_number, data: '[]',
                           notification_type: Notification.types[:liked])
      p2.trash!(p.user)

      # we may want to make notification "trashable" but for now we nuke pm notifications from deleted topics/posts
      Notification.ensure_consistency!

      expect(Notification.count).to eq(2)
    end
  end

end

# pulling this out cause I don't want an observer
describe Notification do
  describe '#recent_report' do
    let(:user){ Fabricate(:user) }
    let(:post){ Fabricate(:post) }

    def fab(type, read)
      @i ||= 0
      @i += 1
      Notification.create!(read: read, user_id: user.id, topic_id: post.topic_id, post_number: post.post_number, data: '[]',
                           notification_type: type, created_at: @i.days.from_now)
    end

    def unread_pm
      fab(Notification.types[:private_message], false)
    end

    def pm
      fab(Notification.types[:private_message], true)
    end

    def regular
      fab(Notification.types[:liked], true)
    end

    it 'correctly finds visible notifications' do
      pm
      expect(Notification.visible.count).to eq(1)
      post.topic.trash!
      expect(Notification.visible.count).to eq(0)
    end

    it 'orders stuff correctly' do
      a = unread_pm
          regular
      c = pm
      d = regular

      # bumps unread pms to front of list

      notifications = Notification.recent_report(user, 3)
      expect(notifications.map{|n| n.id}).to eq([a.id, d.id, c.id])

    end
  end
end
