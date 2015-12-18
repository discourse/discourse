require 'rails_helper'

describe UserEmailObserver do

  # something is off with fabricator
  def create_notification(type, user=nil)
    user ||= Fabricate(:user)
    Notification.create(data: '', user: user, notification_type: type)
  end

  shared_examples "enqueue" do

    it "enqueues a job for the email" do
      Jobs.expects(:enqueue_in).with(delay, :user_email, type: type, user_id: notification.user_id, notification_id: notification.id)
      UserEmailObserver.send(:new).after_commit(notification)
    end

    context "inactive user" do

      before { notification.user.active = false }

      it "doesn't enqueue a job" do
        Jobs.expects(:enqueue_in).with(delay, :user_email, has_entry(type: type)).never
        UserEmailObserver.send(:new).after_commit(notification)
      end

      it "enqueues a job if the user is staged" do
        notification.user.staged = true
        Jobs.expects(:enqueue_in).with(delay, :user_email, type: type, user_id: notification.user_id, notification_id: notification.id)
        UserEmailObserver.send(:new).after_commit(notification)
      end

    end

  end

  shared_examples "enqueue_public" do
    include_examples "enqueue"

    it "doesn't enqueue a job if the user has mention emails disabled" do
      notification.user.expects(:email_direct?).returns(false)
      Jobs.expects(:enqueue_in).with(delay, :user_email, has_entry(type: type)).never
      UserEmailObserver.send(:new).after_commit(notification)
    end
  end

  shared_examples "enqueue_private" do
    include_examples "enqueue"

    it "doesn't enqueue a job if the user has private message emails disabled" do
      notification.user.expects(:email_private_messages?).returns(false)
      Jobs.expects(:enqueue_in).with(delay, :user_email, has_entry(type: type)).never
      UserEmailObserver.send(:new).after_commit(notification)
    end
  end

  context 'user_mentioned' do
    let(:type) { :user_mentioned }
    let(:delay) { SiteSetting.email_time_window_mins.minutes }
    let!(:notification) { create_notification(1) }

    include_examples "enqueue_public"

    it "enqueue a delayed job for users that are online" do
      notification.user.last_seen_at = 1.minute.ago
      Jobs.expects(:enqueue_in).with(delay, :user_email, type: type, user_id: notification.user_id, notification_id: notification.id)
      UserEmailObserver.send(:new).after_commit(notification)
    end

  end

  context 'user_replied' do
    let(:type) { :user_replied }
    let(:delay) { SiteSetting.email_time_window_mins.minutes }
    let!(:notification) { create_notification(2) }

    include_examples "enqueue_public"
  end

  context 'user_quoted' do
    let(:type) { :user_quoted }
    let(:delay) { SiteSetting.email_time_window_mins.minutes }
    let!(:notification) { create_notification(3) }

    include_examples "enqueue_public"
  end

  context 'user_posted' do
    let(:type) { :user_posted }
    let(:delay) { SiteSetting.email_time_window_mins.minutes }
    let!(:notification) { create_notification(9) }

    include_examples "enqueue_public"
  end

  context 'user_private_message' do
    let(:type) { :user_private_message }
    let(:delay) { 0 }
    let!(:notification) { create_notification(6) }

    include_examples "enqueue_private"
  end

  context 'user_invited_to_private_message' do
    let(:type) { :user_invited_to_private_message }
    let(:delay) { 0 }
    let!(:notification) { create_notification(7) }

    include_examples "enqueue_public"
  end

  context 'user_invited_to_topic' do
    let(:type) { :user_invited_to_topic }
    let(:delay) { 0 }
    let!(:notification) { create_notification(13) }

    include_examples "enqueue_public"
  end

end
