require 'spec_helper'

describe UserEmailObserver do

  context 'user_mentioned' do

    let(:user) { Fabricate(:user) }
    let!(:notification) { Fabricate(:notification, user: user) }

    it "enqueues a job for the email" do
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, type: :user_mentioned, user_id: notification.user_id, notification_id: notification.id)
      UserEmailObserver.send(:new).after_commit(notification)
    end

    it "enqueue a delayed job for users that are online" do
      user.last_seen_at = 1.minute.ago
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, type: :user_mentioned, user_id: notification.user_id, notification_id: notification.id)
      UserEmailObserver.send(:new).after_commit(notification)
    end

    it "doesn't enqueue an email if the user has mention emails disabled" do
      user.expects(:email_direct?).returns(false)
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, has_entry(type: :user_mentioned)).never
      UserEmailObserver.send(:new).after_commit(notification)
    end

    it "doesn't enqueue an email if the user account is deactivated" do
      user.active = false
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, has_entry(type: :user_mentioned)).never
      UserEmailObserver.send(:new).after_commit(notification)
    end

  end

  context 'posted' do

    let(:user) { Fabricate(:user) }
    let!(:notification) { Fabricate(:notification, user: user, notification_type: 9) }

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

    let(:user) { Fabricate(:user) }
    let!(:notification) { Fabricate(:notification, user: user, notification_type: 2) }

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

    let(:user) { Fabricate(:user) }
    let!(:notification) { Fabricate(:notification, user: user, notification_type: 3) }

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

    let(:user) { Fabricate(:user) }
    let!(:notification) { Fabricate(:notification, user: user, notification_type: 7) }

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

    let(:user) { Fabricate(:user) }
    let!(:notification) { Fabricate(:notification, user: user, notification_type: 6) }

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

  context 'private_message' do

    let(:user) { Fabricate(:user) }
    let!(:notification) { Fabricate(:notification, user: user, notification_type: 6) }

    it "enqueues a job for the email" do
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, type: :user_private_message, user_id: notification.user_id, notification_id: notification.id)
      UserEmailObserver.send(:new).after_commit(notification)
    end

    it "doesn't enqueue an email if the user has private message emails disabled" do
      user.expects(:email_private_messages?).returns(false)
      Jobs.expects(:enqueue_in).with(SiteSetting.email_time_window_mins.minutes, :user_email, has_entry(type: :user_private_message)).never
      UserEmailObserver.send(:new).after_commit(notification)
    end

  end

  context 'user_invited_to_topic' do

    let(:user) { Fabricate(:user) }
    let!(:notification) { Fabricate(:notification, user: user, notification_type: 13) }

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
