require 'rails_helper'

describe NotificationEmailer do

  before do
    NotificationEmailer.enable
  end

  let(:topic) { Fabricate(:topic) }
  let(:post) { Fabricate(:post, topic: topic) }

  # something is off with fabricator
  def create_notification(type, user = nil)
    user ||= Fabricate(:user)
    Notification.create(data: "{\"a\": 1}",
                        user: user,
                        notification_type: Notification.types[type],
                        topic: topic,
                        post_number: post.post_number)
  end

  shared_examples "enqueue" do

    it "enqueues a job for the email" do
      Jobs.expects(:enqueue_in).with(delay, :user_email, NotificationEmailer::EmailUser.notification_params(notification, type))
      NotificationEmailer.process_notification(notification)
    end

    context "inactive user" do
      before { notification.user.active = false }

      it "doesn't enqueue a job" do
        Jobs.expects(:enqueue_in).with(delay, :user_email, has_entry(type: type)).never
        NotificationEmailer.process_notification(notification)
      end

      it "enqueues a job if the user is staged" do
        notification.user.staged = true
        Jobs.expects(:enqueue_in).with(delay, :user_email, NotificationEmailer::EmailUser.notification_params(notification, type))
        NotificationEmailer.process_notification(notification)
      end

      it "enqueues a job if the user is staged even if site requires user approval" do
        SiteSetting.must_approve_users = true

        notification.user.staged = true
        Jobs.expects(:enqueue_in).with(delay, :user_email, NotificationEmailer::EmailUser.notification_params(notification, type))
        NotificationEmailer.process_notification(notification)
      end
    end

    context "active but unapproved user" do
      before do
        SiteSetting.must_approve_users = true
        notification.user.approved = false
        notification.user.active = true
      end

      it "doesn't enqueue a job" do
        Jobs.expects(:enqueue_in).with(delay, :user_email, has_entry(type: type)).never
        NotificationEmailer.process_notification(notification)
      end
    end

    context "small action" do

      it "doesn't enqueue a job" do
        Post.any_instance.expects(:post_type).returns(Post.types[:small_action])
        Jobs.expects(:enqueue_in).with(delay, :user_email, has_entry(type: type)).never
        NotificationEmailer.process_notification(notification)
      end

    end

  end

  shared_examples "enqueue_public" do
    include_examples "enqueue"

    it "doesn't enqueue a job if the user has mention emails disabled" do
      notification.user.user_option.update_columns(email_direct: false)
      Jobs.expects(:enqueue_in).with(delay, :user_email, has_entry(type: type)).never
      NotificationEmailer.process_notification(notification)
    end
  end

  shared_examples "enqueue_private" do
    include_examples "enqueue"

    it "doesn't enqueue a job if the user has private message emails disabled" do
      notification.user.user_option.update_columns(email_private_messages: false)
      Jobs.expects(:enqueue_in).with(delay, :user_email, has_entry(type: type)).never
      NotificationEmailer.process_notification(notification)
    end

  end

  context 'user_mentioned' do
    let(:type) { :user_mentioned }
    let(:delay) { SiteSetting.email_time_window_mins.minutes }
    let!(:notification) { create_notification(:mentioned) }

    include_examples "enqueue_public"

    it "enqueue a delayed job for users that are online" do
      notification.user.last_seen_at = 1.minute.ago
      Jobs.expects(:enqueue_in).with(delay, :user_email, NotificationEmailer::EmailUser.notification_params(notification, type))
      NotificationEmailer.process_notification(notification)
    end

  end

  context 'user_replied' do
    let(:type) { :user_replied }
    let(:delay) { SiteSetting.email_time_window_mins.minutes }
    let!(:notification) { create_notification(:replied) }

    include_examples "enqueue_public"
  end

  context 'user_quoted' do
    let(:type) { :user_quoted }
    let(:delay) { SiteSetting.email_time_window_mins.minutes }
    let!(:notification) { create_notification(:quoted) }

    include_examples "enqueue_public"
  end

  context 'user_linked' do
    let(:type) { :user_linked }
    let(:delay) { SiteSetting.email_time_window_mins.minutes }
    let!(:notification) { create_notification(:linked) }

    include_examples "enqueue_public"
  end

  context 'user_posted' do
    let(:type) { :user_posted }
    let(:delay) { SiteSetting.email_time_window_mins.minutes }
    let!(:notification) { create_notification(:posted) }

    include_examples "enqueue_public"
  end

  context 'user_private_message' do
    let(:type) { :user_private_message }
    let(:delay) { SiteSetting.personal_email_time_window_seconds }
    let!(:notification) { create_notification(:private_message) }

    include_examples "enqueue_private"

    it "doesn't enqueue a job for a small action" do
      notification.data_hash["original_post_type"] = Post.types[:small_action]
      Jobs.expects(:enqueue_in).with(delay, :user_email, has_entry(type: type)).never
      NotificationEmailer.process_notification(notification)
    end

  end

  context 'user_invited_to_private_message' do
    let(:type) { :user_invited_to_private_message }
    let(:delay) { SiteSetting.personal_email_time_window_seconds }
    let!(:notification) { create_notification(:invited_to_private_message) }

    include_examples "enqueue_public"
  end

  context 'user_invited_to_topic' do
    let(:type) { :user_invited_to_topic }
    let(:delay) { SiteSetting.personal_email_time_window_seconds }
    let!(:notification) { create_notification(:invited_to_topic) }

    include_examples "enqueue_public"
  end

  context 'watching the first post' do
    let(:type) { :user_watching_first_post }
    let(:delay) { SiteSetting.email_time_window_mins.minutes }
    let!(:notification) { create_notification(:watching_first_post) }

    include_examples "enqueue_public"
  end

end
