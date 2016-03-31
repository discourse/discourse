require 'rails_helper'

describe UserEmailObserver do

  let(:topic) { Fabricate(:topic) }
  let(:post) { Fabricate(:post, topic: topic) }

  # something is off with fabricator
  def create_notification(type, user=nil)
    user ||= Fabricate(:user)
    Notification.create(data: "{\"a\": 1}", user: user, notification_type: type, topic: topic, post_number: post.post_number)
  end

  shared_examples "enqueue" do

    it "enqueues a job for the email" do
      Jobs.expects(:enqueue_in).with(delay, :user_email, UserEmailObserver::EmailUser.notification_params(notification,type))
      UserEmailObserver.process_notification(notification)
    end

    context "inactive user" do

      before { notification.user.active = false }

      it "doesn't enqueue a job" do
        Jobs.expects(:enqueue_in).with(delay, :user_email, has_entry(type: type)).never
        UserEmailObserver.process_notification(notification)
      end

      it "enqueues a job if the user is staged" do
        notification.user.staged = true
        Jobs.expects(:enqueue_in).with(delay, :user_email, UserEmailObserver::EmailUser.notification_params(notification,type))
        UserEmailObserver.process_notification(notification)
      end

    end

    context "small action" do

      it "doesn't enqueue a job" do
        Post.any_instance.expects(:post_type).returns(Post.types[:small_action])
        Jobs.expects(:enqueue_in).with(delay, :user_email, has_entry(type: type)).never
        UserEmailObserver.process_notification(notification)
      end

    end

  end

  shared_examples "enqueue_public" do
    include_examples "enqueue"

    it "doesn't enqueue a job if the user has mention emails disabled" do
      notification.user.user_option.update_columns(email_direct: false)
      Jobs.expects(:enqueue_in).with(delay, :user_email, has_entry(type: type)).never
      UserEmailObserver.process_notification(notification)
    end
  end

  shared_examples "enqueue_private" do
    include_examples "enqueue"

    it "doesn't enqueue a job if the user has private message emails disabled" do
      notification.user.user_option.update_columns(email_private_messages: false)
      Jobs.expects(:enqueue_in).with(delay, :user_email, has_entry(type: type)).never
      UserEmailObserver.process_notification(notification)
    end

  end

  context 'user_mentioned' do
    let(:type) { :user_mentioned }
    let(:delay) { SiteSetting.email_time_window_mins.minutes }
    let!(:notification) { create_notification(1) }

    include_examples "enqueue_public"

    it "enqueue a delayed job for users that are online" do
      notification.user.last_seen_at = 1.minute.ago
      Jobs.expects(:enqueue_in).with(delay, :user_email, UserEmailObserver::EmailUser.notification_params(notification,type))
      UserEmailObserver.process_notification(notification)
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

  context 'user_linked' do
    let(:type) { :user_linked }
    let(:delay) { SiteSetting.email_time_window_mins.minutes }
    let!(:notification) { create_notification(11) }

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
    let(:delay) { SiteSetting.private_email_time_window_seconds }
    let!(:notification) { create_notification(6) }

    include_examples "enqueue_private"

    it "doesn't enqueue a job for a small action" do
      notification.data_hash["original_post_type"] = Post.types[:small_action]
      Jobs.expects(:enqueue_in).with(delay, :user_email, has_entry(type: type)).never
      UserEmailObserver.process_notification(notification)
    end

  end

  context 'user_invited_to_private_message' do
    let(:type) { :user_invited_to_private_message }
    let(:delay) { SiteSetting.private_email_time_window_seconds }
    let!(:notification) { create_notification(7) }

    include_examples "enqueue_public"
  end

  context 'user_invited_to_topic' do
    let(:type) { :user_invited_to_topic }
    let(:delay) { SiteSetting.private_email_time_window_seconds }
    let!(:notification) { create_notification(13) }

    include_examples "enqueue_public"
  end

end
