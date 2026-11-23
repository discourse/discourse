# frozen_string_literal: true

RSpec.describe NotificationEmailer do
  before do
    freeze_time
    NotificationEmailer.enable
  end

  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }

  fab!(:notification_user, :user)
  let(:notification) do
    Notification.create(
      data: "{\"a\": 1}",
      user: notification_user,
      notification_type: Notification.types[notification_kind],
      topic: topic,
      post_number: post.post_number,
      skip_send_email: true,
    )
  end

  it "does not email interactive bots for notifications created outside PostAlerter" do
    bot = Fabricate(:bot, interactive_bot: true)
    bot.user_option.update!(email_level: UserOption.email_level_types[:always])
    notice =
      Fabricate(
        :notification,
        user: bot,
        topic:,
        post_number: post.post_number,
        notification_type: Notification.types[:invited_to_private_message],
        skip_send_email: true,
      )

    expect_not_enqueued_with(job: :user_email, args: { user_id: bot.id }) do
      NotificationEmailer.process_notification(notice, no_delay: true)
    end
  end

  describe ".process_notification" do
    let(:notification_kind) { :replied }

    shared_examples "an email notification" do |kind, job_type, personal: false|
      let(:notification_kind) { kind }

      it "enqueues the corresponding email with and without a delay" do
        delay =
          if personal
            SiteSetting.personal_email_time_window_seconds.seconds
          else
            SiteSetting.email_time_window_mins.minutes
          end
        args = {
          type: job_type.to_s,
          notification_id: notification.id,
          user_id: notification_user.id,
        }

        expect_enqueued_with(job: :user_email, args:, at: Time.zone.now + delay) do
          described_class.process_notification(notification)
        end
        expect_enqueued_with(job: :user_email, args:, at: Time.zone.now) do
          described_class.process_notification(notification, no_delay: true)
        end
      end
    end

    context "with a mention" do
      include_examples "an email notification", :mentioned, :user_mentioned
    end

    context "with a reply" do
      include_examples "an email notification", :replied, :user_replied
    end

    context "with a quote" do
      include_examples "an email notification", :quoted, :user_quoted
    end

    context "with a link" do
      include_examples "an email notification", :linked, :user_linked
    end

    context "with a new post" do
      include_examples "an email notification", :posted, :user_posted
    end

    context "with a watched category or tag" do
      include_examples "an email notification", :watching_category_or_tag, :user_posted
    end

    context "with an invitation to a private message" do
      include_examples "an email notification",
                       :invited_to_private_message,
                       :user_invited_to_private_message,
                       personal: true
    end

    context "with an invitation to a topic" do
      include_examples "an email notification",
                       :invited_to_topic,
                       :user_invited_to_topic,
                       personal: true
    end

    context "with a watched first post" do
      include_examples "an email notification", :watching_first_post, :user_watching_first_post
    end

    context "with an approved post" do
      include_examples "an email notification", :post_approved, :post_approved
    end

    it "delays a mention email for an online user" do
      notice = Fabricate(:notification, user: notification_user, post: post, skip_send_email: true)
      notification_user.last_seen_at = 1.minute.ago

      expect_enqueued_with(
        job: :user_email,
        args: {
          notification_id: notice.id,
        },
        at: Time.zone.now + SiteSetting.email_time_window_mins.minutes,
      ) { described_class.process_notification(notice) }
    end

    it "does not email inactive users" do
      notification_user.active = false

      expect_not_enqueued_with(job: :user_email) do
        described_class.process_notification(notification)
      end
    end

    it "does not email unapproved users when approval is required" do
      SiteSetting.must_approve_users = true
      notification_user.approved = false

      expect_not_enqueued_with(job: :user_email) do
        described_class.process_notification(notification)
      end
    end

    context "with a staged user" do
      before do
        notification_user.active = false
        notification_user.approved = false
        notification_user.staged = true
        SiteSetting.must_approve_users = true
      end

      it "sends reply emails even when approval is required" do
        expect_enqueued_with(job: :user_email, args: { notification_id: notification.id }) do
          described_class.process_notification(notification)
        end
      end

      it "does not send linked or quoted emails" do
        %i[linked quoted].each do |kind|
          notice =
            Fabricate(
              :notification,
              user: notification_user,
              post: post,
              notification_type: Notification.types[kind],
              skip_send_email: true,
            )
          expect_not_enqueued_with(job: :user_email) do
            described_class.process_notification(notice)
          end
        end
      end
    end

    it "respects the user's public email preference" do
      notification_user.user_option.update!(email_level: UserOption.email_level_types[:never])

      expect_not_enqueued_with(job: :user_email) do
        described_class.process_notification(notification)
      end
    end

    context "with a private message" do
      include_examples "an email notification",
                       :private_message,
                       :user_private_message,
                       personal: true

      it "respects the user's private message email preference" do
        notification_user.user_option.update!(
          email_messages_level: UserOption.email_level_types[:never],
        )

        expect_not_enqueued_with(job: :user_email) do
          described_class.process_notification(notification)
        end
      end

      it "uses the original post type to suppress small action emails" do
        notification.data_hash["original_post_type"] = Post.types[:small_action]

        expect_not_enqueued_with(job: :user_email) do
          described_class.process_notification(notification)
        end
      end
    end

    it "emails notifications about moderator actions" do
      post.update!(post_type: Post.types[:moderator_action])

      expect_enqueued_with(job: :user_email, args: { notification_id: notification.id }) do
        described_class.process_notification(notification)
      end
    end

    it "does not email notifications about small actions" do
      post.update!(post_type: Post.types[:small_action])

      expect_not_enqueued_with(job: :user_email) do
        described_class.process_notification(notification)
      end
    end
  end

  it "has translations for each sendable notification type" do
    notification =
      Notification.create(
        data: "{\"a\": 1}",
        user: Fabricate(:user),
        notification_type: Notification.types[:mentioned],
        topic: topic,
        post_number: post.post_number,
        skip_send_email: true,
      )
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

  describe "with plugin-added email_notification_filters" do
    let!(:plugin) { Plugin::Instance.new }
    let(:notification_kind) { :quoted }
    let(:no_delay) { true }
    let(:type) { :user_quoted }

    after { DiscoursePluginRegistry.reset_register! :email_notification_filters }

    it "sends email when all filters return true" do
      plugin.register_email_notification_filter { |_| true }
      plugin.register_email_notification_filter { |_| true }

      expect_enqueued_with(job: :user_email, args: { type: type }) do
        NotificationEmailer.process_notification(notification, no_delay: no_delay)
      end
    end

    it "doesn't send email when all one filter returns false" do
      plugin.register_email_notification_filter { |_| true }
      plugin.register_email_notification_filter { |_| false }

      expect_not_enqueued_with(job: :user_email, args: { type: type }) do
        NotificationEmailer.process_notification(notification, no_delay: no_delay)
      end
    end
  end

  context "with a staged user" do
    context "when notification is mentioned or group_mentioned type" do
      it "doesn't enqueue the job to send user email" do
        staged_user = Fabricate(:staged)
        notification_attributes = {
          data: "{\"a\": 1}",
          user: staged_user,
          topic: topic,
          post_number: post.post_number,
          skip_send_email: true,
        }
        mentioned =
          Notification.create(
            **notification_attributes,
            notification_type: Notification.types[:mentioned],
          )
        group_mentioned =
          Notification.create(
            **notification_attributes,
            notification_type: Notification.types[:group_mentioned],
          )

        expect_not_enqueued_with(job: :user_email) do
          NotificationEmailer.process_notification(mentioned, no_delay: Time.zone.now)
        end

        expect_not_enqueued_with(job: :user_email) do
          NotificationEmailer.process_notification(group_mentioned, no_delay: Time.zone.now)
        end
      end
    end
  end
end
