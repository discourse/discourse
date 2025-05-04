# frozen_string_literal: true

RSpec.describe PushNotificationPusher do
  it "returns badges url by default" do
    expect(PushNotificationPusher.get_badge).to match(
      %r{\A/assets/push-notifications/discourse-\w{8}.png\z},
    )
  end

  it "returns custom badges url" do
    upload = Fabricate(:upload)
    SiteSetting.push_notifications_icon = upload

    expect(PushNotificationPusher.get_badge).to eq(UrlHelper.absolute(upload.url))
  end

  context "with user" do
    fab!(:user)
    let(:topic_title) { "Topic" }
    let(:base_url) { Discourse.base_url }
    let(:post_url) { "/base/t/1/2" }
    let(:username) { "system" }

    before { Discourse.stubs(base_path: "/base") }

    def create_subscription
      data = <<~JSON
      {
        "endpoint": "endpoint",
        "keys": {
          "p256dh": "p256dh",
          "auth": "auth"
        }
      }
      JSON
      PushSubscription.create!(user_id: user.id, data: data)
    end

    def execute_push(notification_type: 1, post_number: 1)
      PushNotificationPusher.push(
        user,
        {
          topic_title: topic_title,
          username: username,
          excerpt: "description",
          topic_id: 1,
          base_url: base_url,
          post_url: post_url,
          notification_type: notification_type,
          post_number: post_number,
        },
      )
    end

    it "correctly guesses an image if missing" do
      message = execute_push(notification_type: -1)
      expect(message[:icon]).to match(%r{\A/assets/push-notifications/discourse-\w{8}.png\z})
    end

    it "correctly finds image if exists" do
      message = execute_push(notification_type: 1)
      expect(message[:icon]).to match(%r{\A/assets/push-notifications/mentioned-\w{8}.png\z})
    end

    it "sends notification in user's locale" do
      SiteSetting.allow_user_locale = true
      user.update!(locale: "pt_BR")

      TranslationOverride.upsert!(
        "pt_BR",
        "discourse_push_notifications.popup.mentioned",
        "pt_BR notification",
      )

      WebPush
        .expects(:payload_send)
        .with { |*args| JSON.parse(args.first[:message])["title"] == "pt_BR notification" }
        .once

      create_subscription
      execute_push
    end

    it "triggers a DiscourseEvent with user and message arguments" do
      WebPush.expects(:payload_send)
      create_subscription
      pn_sent_event = DiscourseEvent.track_events { message = execute_push }.first

      expect(pn_sent_event[:event_name]).to eq(:push_notification_sent)
      expect(pn_sent_event[:params].first).to eq(user)
      expect(pn_sent_event[:params].second[:url]).to eq("/t/1/2")
    end

    it "triggers a DiscourseEvent with base_path stripped from the url when present" do
      WebPush.expects(:payload_send)
      create_subscription
      pn_sent_event = DiscourseEvent.track_events { message = execute_push }.first

      expect(pn_sent_event[:event_name]).to eq(:push_notification_sent)
      expect(pn_sent_event[:params].first).to eq(user)
      expect(pn_sent_event[:params].second[:url]).to eq("/t/1/2")
      expect(pn_sent_event[:params].second[:base_url]).to eq(base_url)
    end

    it "deletes subscriptions which are erroring regularly" do
      start = freeze_time

      sub = create_subscription

      response = Struct.new(:body, :inspect, :message).new("test", "test", "failed")
      error = WebPush::ResponseError.new(response, "localhost")

      WebPush.expects(:payload_send).raises(error).times(4)

      # 3 failures in more than 24 hours
      3.times do
        execute_push

        freeze_time 1.minute.from_now
      end

      sub.reload
      expect(sub.error_count).to eq(3)
      expect(sub.first_error_at).to eq_time(start)

      freeze_time(2.days.from_now)

      execute_push

      expect(PushSubscription.where(id: sub.id).exists?).to eq(false)
    end

    it "deletes invalid subscriptions during send" do
      missing_endpoint =
        PushSubscription.create!(
          user_id: user.id,
          data: { p256dh: "public ECDH key", keys: { auth: "private ECDH key" } }.to_json,
        )

      missing_p256dh =
        PushSubscription.create!(
          user_id: user.id,
          data: { endpoint: "endpoint 1", keys: { auth: "private ECDH key" } }.to_json,
        )

      missing_auth =
        PushSubscription.create!(
          user_id: user.id,
          data: { endpoint: "endpoint 2", keys: { p256dh: "public ECDH key" } }.to_json,
        )

      valid_subscription =
        PushSubscription.create!(
          user_id: user.id,
          data: {
            endpoint: "endpoint 3",
            keys: {
              p256dh: "public ECDH key",
              auth: "private ECDH key",
            },
          }.to_json,
        )

      expect(PushSubscription.where(user_id: user.id)).to contain_exactly(
        missing_endpoint,
        missing_p256dh,
        missing_auth,
        valid_subscription,
      )
      WebPush
        .expects(:payload_send)
        .with(
          has_entries(endpoint: "endpoint 3", p256dh: "public ECDH key", auth: "private ECDH key"),
        )
        .once

      execute_push

      expect(PushSubscription.where(user_id: user.id)).to contain_exactly(valid_subscription)
    end

    it "handles timeouts" do
      WebPush.expects(:payload_send).raises(Net::ReadTimeout.new)
      subscription = create_subscription

      expect { execute_push }.to_not raise_exception

      subscription.reload
      expect(subscription.error_count).to eq(1)
    end

    describe "`watching_category_or_tag` notifications" do
      it "Uses the 'watching_first_post' translation when new topic was created" do
        message =
          execute_push(
            notification_type: Notification.types[:watching_category_or_tag],
            post_number: 1,
          )

        expect(message[:title]).to eq(
          I18n.t(
            "discourse_push_notifications.popup.watching_first_post",
            site_title: SiteSetting.title,
            topic: topic_title,
            username: username,
          ),
        )
      end

      it "Uses the 'posted' translation when new post was created" do
        message =
          execute_push(
            notification_type: Notification.types[:watching_category_or_tag],
            post_number: 2,
          )

        expect(message[:title]).to eq(
          I18n.t(
            "discourse_push_notifications.popup.posted",
            site_title: SiteSetting.title,
            topic: topic_title,
            username: username,
          ),
        )
      end
    end

    describe "push_notification_pusher_title_payload modifier" do
      let(:modifier_block) do
        Proc.new do |payload|
          payload[:username] = "super_hijacked"
          payload
        end
      end
      it "Allows modifications to the payload passed to the translation" do
        plugin_instance = Plugin::Instance.new
        plugin_instance.register_modifier(:push_notification_pusher_title_payload, &modifier_block)

        message = execute_push(notification_type: Notification.types[:mentioned], post_number: 2)

        expect(message[:title]).to eq(
          I18n.t(
            "discourse_push_notifications.popup.mentioned",
            site_title: SiteSetting.title,
            topic: topic_title,
            username: "super_hijacked",
          ),
        )
      ensure
        DiscoursePluginRegistry.unregister_modifier(
          plugin_instance,
          :push_notification_pusher_title_payload,
          &modifier_block
        )
      end
    end
  end
end
