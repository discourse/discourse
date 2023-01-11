# frozen_string_literal: true

RSpec.describe NotificationEmailer do
  before do
    freeze_time
    NotificationEmailer.enable
  end

  fab!(:topic) { Fabricate(:topic) }
  fab!(:post) { Fabricate(:post, topic: topic) }

  # something is off with fabricator
  def create_notification(type, user = nil)
    user ||= Fabricate(:user)
    Notification.create(
      data: "{\"a\": 1}",
      user: user,
      notification_type: Notification.types[type],
      topic: topic,
      post_number: post.post_number,
    )
  end

  shared_examples "enqueue" do
    it "enqueues a job for the email" do
      expect_enqueued_with(
        job: :user_email,
        args: NotificationEmailer::EmailUser.notification_params(notification, type),
        at: no_delay ? Time.zone.now : Time.zone.now + delay,
      ) { NotificationEmailer.process_notification(notification, no_delay: no_delay) }
    end

    context "with an inactive user" do
      before { notification.user.active = false }

      it "doesn't enqueue a job" do
        expect_not_enqueued_with(job: :user_email, args: { type: type }) do
          NotificationEmailer.process_notification(notification, no_delay: no_delay)
        end
      end

      it "enqueues a job if the user is staged for non-linked and non-quoted types" do
        notification.user.staged = true

        if type == :user_linked || type == :user_quoted
          expect_not_enqueued_with(job: :user_email, args: { type: type }) do
            NotificationEmailer.process_notification(notification, no_delay: no_delay)
          end
        else
          expect_enqueued_with(
            job: :user_email,
            args: NotificationEmailer::EmailUser.notification_params(notification, type),
            at: no_delay ? Time.zone.now : Time.zone.now + delay,
          ) { NotificationEmailer.process_notification(notification, no_delay: no_delay) }
        end
      end

      it "enqueues a job if the user is staged even if site requires user approval for non-linked and non-quoted typed" do
        notification.user.staged = true
        SiteSetting.must_approve_users = true

        if type == :user_linked || type == :user_quoted
          expect_not_enqueued_with(job: :user_email, args: { type: type }) do
            NotificationEmailer.process_notification(notification, no_delay: no_delay)
          end
        else
          expect_enqueued_with(
            job: :user_email,
            args: NotificationEmailer::EmailUser.notification_params(notification, type),
            at: no_delay ? Time.zone.now : Time.zone.now + delay,
          ) { NotificationEmailer.process_notification(notification, no_delay: no_delay) }
        end
      end
    end

    context "with an active but unapproved user" do
      before do
        SiteSetting.must_approve_users = true
        notification.user.approved = false
        notification.user.active = true
      end

      it "doesn't enqueue a job" do
        expect_not_enqueued_with(job: :user_email, args: { type: type }) do
          NotificationEmailer.process_notification(notification, no_delay: no_delay)
        end
      end
    end

    context "with a small action" do
      it "doesn't enqueue a job" do
        Post.any_instance.expects(:post_type).returns(Post.types[:small_action])

        expect_not_enqueued_with(job: :user_email, args: { type: type }) do
          NotificationEmailer.process_notification(notification, no_delay: no_delay)
        end
      end
    end
  end

  shared_examples "enqueue_public" do
    include_examples "enqueue"

    it "doesn't enqueue a job if the user has mention emails disabled" do
      notification.user.user_option.update_columns(
        email_level: UserOption.email_level_types[:never],
      )

      expect_not_enqueued_with(job: :user_email, args: { type: type }) do
        NotificationEmailer.process_notification(notification, no_delay: no_delay)
      end
    end
  end

  shared_examples "enqueue_private" do
    include_examples "enqueue"

    it "doesn't enqueue a job if the user has private message emails disabled" do
      notification.user.user_option.update_columns(
        email_messages_level: UserOption.email_level_types[:never],
      )

      expect_not_enqueued_with(job: :user_email, args: { type: type }) do
        NotificationEmailer.process_notification(notification)
      end
    end
  end

  [true, false].each do |no_delay|
    context "with user_mentioned" do
      let(:no_delay) { no_delay }
      let(:type) { :user_mentioned }
      let(:delay) { SiteSetting.email_time_window_mins.minutes }
      let!(:notification) { create_notification(:mentioned) }

      include_examples "enqueue_public"

      it "enqueue a delayed job for users that are online" do
        notification.user.last_seen_at = 1.minute.ago

        expect_enqueued_with(
          job: :user_email,
          args: NotificationEmailer::EmailUser.notification_params(notification, type),
          at: Time.zone.now + delay,
        ) { NotificationEmailer.process_notification(notification) }
      end
    end

    context "with user_replied" do
      let(:no_delay) { no_delay }
      let(:type) { :user_replied }
      let(:delay) { SiteSetting.email_time_window_mins.minutes }
      let!(:notification) { create_notification(:replied) }

      include_examples "enqueue_public"
    end

    context "with user_quoted" do
      let(:no_delay) { no_delay }
      let(:type) { :user_quoted }
      let(:delay) { SiteSetting.email_time_window_mins.minutes }
      let!(:notification) { create_notification(:quoted) }

      include_examples "enqueue_public"
    end

    context "with user_linked" do
      let(:no_delay) { no_delay }
      let(:type) { :user_linked }
      let(:delay) { SiteSetting.email_time_window_mins.minutes }
      let!(:notification) { create_notification(:linked) }

      include_examples "enqueue_public"
    end

    context "with user_posted" do
      let(:no_delay) { no_delay }
      let(:type) { :user_posted }
      let(:delay) { SiteSetting.email_time_window_mins.minutes }
      let!(:notification) { create_notification(:posted) }

      include_examples "enqueue_public"
    end

    context "with user_watching_category_or_tag" do
      let(:no_delay) { no_delay }
      let(:type) { :user_posted }
      let(:delay) { SiteSetting.email_time_window_mins.minutes }
      let!(:notification) { create_notification(:watching_category_or_tag) }

      include_examples "enqueue_public"
    end

    context "with user_private_message" do
      let(:no_delay) { no_delay }
      let(:type) { :user_private_message }
      let(:delay) { SiteSetting.personal_email_time_window_seconds }
      let!(:notification) { create_notification(:private_message) }

      include_examples "enqueue_private"

      it "doesn't enqueue a job for a small action" do
        notification.data_hash["original_post_type"] = Post.types[:small_action]

        expect_not_enqueued_with(job: :user_email, args: { type: type }) do
          NotificationEmailer.process_notification(notification)
        end
      end
    end

    context "with user_invited_to_private_message" do
      let(:no_delay) { no_delay }
      let(:type) { :user_invited_to_private_message }
      let(:delay) { SiteSetting.personal_email_time_window_seconds }
      let!(:notification) { create_notification(:invited_to_private_message) }

      include_examples "enqueue_public"
    end

    context "with user_invited_to_topic" do
      let(:no_delay) { no_delay }
      let(:type) { :user_invited_to_topic }
      let(:delay) { SiteSetting.personal_email_time_window_seconds }
      let!(:notification) { create_notification(:invited_to_topic) }

      include_examples "enqueue_public"
    end

    context "when watching the first post" do
      let(:no_delay) { no_delay }
      let(:type) { :user_watching_first_post }
      let(:delay) { SiteSetting.email_time_window_mins.minutes }
      let!(:notification) { create_notification(:watching_first_post) }

      include_examples "enqueue_public"
    end

    context "with post_approved" do
      let(:no_delay) { no_delay }
      let(:type) { :post_approved }
      let(:delay) { SiteSetting.email_time_window_mins.minutes }
      let!(:notification) { create_notification(:post_approved) }

      include_examples "enqueue_public"
    end
  end

  it "has translations for each sendable notification type" do
    notification = create_notification(:mentioned)
    email_user = NotificationEmailer::EmailUser.new(notification, no_delay: true)
    subkeys = %w[title subject_template text_body_template]

    # some notification types need special handling
    replace_keys = {
      "post_approved" => ["post_approved"],
      "private_message" => ["user_posted"],
      "invited_to_private_message" => %w[
        user_invited_to_private_message_pm
        user_invited_to_private_message_pm_group
        user_invited_to_private_message_pm_staged
      ],
    }

    Notification.types.keys.each do |notification_type|
      if email_user.respond_to?(notification_type)
        type_keys = replace_keys[notification_type.to_s] || ["user_#{notification_type}"]

        type_keys.each do |type_key|
          subkeys.each do |subkey|
            key = "user_notifications.#{type_key}.#{subkey}"
            expect(I18n.exists?(key)).to eq(true), "missing translation: #{key}"
          end
        end
      end
    end
  end
end
