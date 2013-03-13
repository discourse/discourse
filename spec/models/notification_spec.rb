require 'spec_helper'

describe Notification do

  it { should validate_presence_of :notification_type }
  it { should validate_presence_of :data }

  it { should belong_to :user }
  it { should belong_to :topic }

  describe 'unread counts' do

    let(:user) { Fabricate(:user) }

    context 'a regular notification' do
      it 'increases unread_notifications' do
        lambda { Fabricate(:notification, user: user); user.reload }.should change(user, :unread_notifications)
      end

      it "doesn't increase unread_private_messages" do
        lambda { Fabricate(:notification, user: user); user.reload }.should_not change(user, :unread_private_messages)
      end
    end

    context 'a private message' do
      it "doesn't increase unread_notifications" do
        lambda { Fabricate(:private_message_notification, user: user); user.reload }.should_not change(user, :unread_notifications)
      end

      it "increases unread_private_messages" do
        lambda { Fabricate(:private_message_notification, user: user); user.reload }.should change(user, :unread_private_messages)
      end
    end

  end

  describe 'message bus' do

    it 'updates the notification count on create' do
      MessageBusObserver.any_instance.expects(:refresh_notification_count).with(instance_of(Notification))
      Fabricate(:notification)
    end

    context 'destroy' do

      let!(:notification) { Fabricate(:notification) }

      it 'updates the notification count on destroy' do
        MessageBusObserver.any_instance.expects(:refresh_notification_count).with(instance_of(Notification))
        notification.destroy
      end

    end
  end

  describe '@mention' do

    it "calls email_user_mentioned on creating a notification" do
      UserEmailObserver.any_instance.expects(:email_user_mentioned).with(instance_of(Notification))
      Fabricate(:notification)
    end

  end

  describe '@mention' do
    it "calls email_user_quoted on creating a quote notification" do
      UserEmailObserver.any_instance.expects(:email_user_quoted).with(instance_of(Notification))
      Fabricate(:quote_notification)
    end
  end

  describe 'private message' do
    before do
      @topic = Fabricate(:private_message_topic)
      @post = Fabricate(:post, :topic => @topic, :user => @topic.user)
      @target = @post.topic.topic_allowed_users.reject{|a| a.user_id == @post.user_id}[0].user
    end

    it 'should create a private message notification' do
      @target.notifications.first.notification_type.should == Notification.types[:private_message]
    end

    it 'should not add a pm notification for the creator' do
      @post.user.unread_notifications.should == 0
    end
  end

  describe '.post' do

    let(:post) { Fabricate(:post) }
    let!(:notification) { Fabricate(:notification, user: post.user, topic: post.topic, post_number: post.post_number) }

    it 'returns the post' do
      notification.post.should == post
    end

  end

  describe 'data' do
    let(:notification) { Fabricate.build(:notification) }

    it 'should have a data hash' do
      notification.data_hash.should be_present
    end

    it 'should have the data within the json' do
      notification.data_hash[:poison].should == 'ivy'
    end
  end

  describe 'mark_posts_read' do
    it "marks multiple posts as read if needed" do
      user = Fabricate(:user)

      notifications = (1..3).map do |i|
        Notification.create!(read: false, user_id: user.id, topic_id: 2, post_number: i, data: '[]', notification_type: 1)
      end
      Notification.create!(read: true, user_id: user.id, topic_id: 2, post_number: 4, data: '[]', notification_type: 1)

      Notification.mark_posts_read(user,2,[1,2,3,4]).should == 3
    end
  end

end
