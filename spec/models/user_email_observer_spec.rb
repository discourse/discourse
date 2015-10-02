require 'spec_helper'

describe UserEmailObserver do

  # something is off with fabricator
  def create_notification(type=nil, user=nil)
    user ||= Fabricate(:user)
    type ||= Notification.types[:mentioned]
    Notification.create(data: '', user: user, notification_type: type)
  end

  context 'user_mentioned' do
    let!(:notification) do
      create_notification
    end

    it "enqueues a job for the email" do
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, type: :user_mentioned, user_id: notification.user_id, notification_id: notification.id)
      UserEmailObserver.send(:new).after_commit(notification)
    end

    it "enqueue a delayed job for users that are online" do
      notification.user.last_seen_at = 1.minute.ago
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, type: :user_mentioned, user_id: notification.user_id, notification_id: notification.id)
      UserEmailObserver.send(:new).after_commit(notification)
    end

    it "doesn't enqueue an email if the user has mention emails disabled" do
      notification.user.expects(:email_direct?).returns(false)
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, has_entry(type: :user_mentioned)).never
      UserEmailObserver.send(:new).after_commit(notification)
    end

    it "doesn't enqueue an email if the user account is deactivated" do
      notification.user.active = false
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, has_entry(type: :user_mentioned)).never
      UserEmailObserver.send(:new).after_commit(notification)
    end

  end

  context 'posted' do

    let!(:notification) { create_notification(9) }
    let(:user) { notification.user }

    it "enqueues a job for the email" do
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, type: :user_posted, user_id: notification.user_id, notification_id: notification.id)
      UserEmailObserver.send(:new).after_commit(notification)
    end

    it "doesn't enqueue an email if the user has mention emails disabled" do
      user.expects(:email_direct?).returns(false)
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, has_entry(type: :user_posted)).never
      UserEmailObserver.send(:new).after_commit(notification)
    end

    it "doesn't enqueue an email if the user account is deactivated" do
      user.active = false
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, has_entry(type: :user_posted)).never
      UserEmailObserver.send(:new).after_commit(notification)
    end

  end

  context 'user_replied' do

    let!(:notification) { create_notification(2) }
    let(:user) { notification.user }

    it "enqueues a job for the email" do
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, type: :user_replied, user_id: notification.user_id, notification_id: notification.id)
      UserEmailObserver.send(:new).after_commit(notification)
    end

    it "doesn't enqueue an email if the user has mention emails disabled" do
      user.expects(:email_direct?).returns(false)
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, has_entry(type: :user_replied)).never
      UserEmailObserver.send(:new).after_commit(notification)
    end

    it "doesn't enqueue an email if the user account is deactivated" do
      user.active = false
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, has_entry(type: :user_replied)).never
      UserEmailObserver.send(:new).after_commit(notification)
    end

  end

  context 'user_quoted' do

    let!(:notification) { create_notification(3) }
    let(:user) { notification.user }

    it "enqueues a job for the email" do
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, type: :user_quoted, user_id: notification.user_id, notification_id: notification.id)
      UserEmailObserver.send(:new).after_commit(notification)
    end

    it "doesn't enqueue an email if the user has mention emails disabled" do
      user.expects(:email_direct?).returns(false)
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, has_entry(type: :user_quoted)).never
      UserEmailObserver.send(:new).after_commit(notification)
    end

    it "doesn't enqueue an email if the user account is deactivated" do
      user.active = false
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, has_entry(type: :user_quoted)).never
      UserEmailObserver.send(:new).after_commit(notification)
    end

  end

  context 'email_user_invited_to_private_message' do

    let!(:notification) { create_notification(7) }
    let(:user) { notification.user }

    it "enqueues a job for the email" do
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, type: :user_invited_to_private_message, user_id: notification.user_id, notification_id: notification.id)
      UserEmailObserver.send(:new).after_commit(notification)
    end

    it "doesn't enqueue an email if the user has mention emails disabled" do
      user.expects(:email_direct?).returns(false)
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, has_entry(type: :user_invited_to_private_message)).never
      UserEmailObserver.send(:new).after_commit(notification)
    end

    it "doesn't enqueue an email if the user account is deactivated" do
      user.active = false
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, has_entry(type: :user_invited_to_private_message)).never
      UserEmailObserver.send(:new).after_commit(notification)
    end

  end

  context 'private_message' do

    let!(:notification) { create_notification(6) }
    let(:user) { notification.user }

    it "enqueues a job for the email" do
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, type: :user_private_message, user_id: notification.user_id, notification_id: notification.id)
      UserEmailObserver.send(:new).after_commit(notification)
    end

    it "doesn't enqueue an email if the user has private message emails disabled" do
      user.expects(:email_private_messages?).returns(false)
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, has_entry(type: :user_private_message)).never
      UserEmailObserver.send(:new).after_commit(notification)
    end

    it "doesn't enqueue an email if the user account is deactivated" do
      user.active = false
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, has_entry(type: :user_private_message)).never
      UserEmailObserver.send(:new).after_commit(notification)
    end

  end

  context 'user_invited_to_topic' do

    let!(:notification) { create_notification(13) }
    let(:user) { notification.user }

    it "enqueues a job for the email" do
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, type: :user_invited_to_topic, user_id: notification.user_id, notification_id: notification.id)
      UserEmailObserver.send(:new).after_commit(notification)
    end

    it "doesn't enqueue an email if the user has mention emails disabled" do
      user.expects(:email_direct?).returns(false)
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, has_entry(type: :user_invited_to_topic)).never
      UserEmailObserver.send(:new).after_commit(notification)
    end

    it "doesn't enqueue an email if the user account is deactivated" do
      user.active = false
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, has_entry(type: :user_invited_to_topic)).never
      UserEmailObserver.send(:new).after_commit(notification)
    end

  end

end
