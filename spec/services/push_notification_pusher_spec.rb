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
    let(:user_auth_token_id) { UserAuthToken.generate!(user_id: user.id).id }
    let(:topic_title) { "Topic" }
    let(:base_url) { Discourse.base_url }
    let(:post_url) { "/base/t/1/2" }
    let(:username) { "system" }

    before { Discourse.stubs(base_path: "/base") }

    def create_subscription
      data = <<~JSON
      {
        "endpoint": "https://fcm.googleapis.com/fcm/send/endpoint",
        "keys": {
          "p256dh": "p256dh",
          "auth": "auth"
        }
      }
      JSON
      PushSubscription.create!(user: user, data: data, user_auth_token_id:)
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

    it "forwards actions and action_data when present in the payload" do
      actions = [
        {
          action: "test-reply",
          title: "Reply",
          placeholder: "Reply…",
          type: "text",
          icon: "https://example.com/icon.png",
        },
      ]
      action_data = { channel_id: 42, thread_id: 7 }

      message =
        PushNotificationPusher.push(
          user,
          {
            topic_title: topic_title,
            username: username,
            excerpt: "description",
            topic_id: 1,
            base_url: base_url,
            post_url: post_url,
            notification_type: 1,
            post_number: 1,
            actions: actions,
            action_data: action_data,
          },
        )

      expect(message[:actions]).to eq(actions)
      expect(message[:action_data]).to eq(action_data)
    end

    it "omits actions and action_data when not present in the payload" do
      message = execute_push
      expect(message).not_to have_key(:actions)
      expect(message).not_to have_key(:action_data)
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

    it "deletes stored subscriptions with revoked endpoints without contacting them" do
      Jobs.run_immediately!
      subscription =
        create_untrusted_subscription("https://permanently-removed.invalid/fcm/send/abc")
      WebPush.expects(:payload_send).never

      execute_push

      expect(PushSubscription.exists?(subscription.id)).to eq(false)
    end

    it "deletes invalid subscriptions during send" do
      Jobs.run_immediately!

      missing_endpoint =
        PushSubscription.create!(
          user: user,
          user_auth_token_id:,
          data: { p256dh: "public ECDH key", keys: { auth: "private ECDH key" } }.to_json,
        )

      missing_p256dh =
        PushSubscription.create!(
          user: user,
          user_auth_token_id:,
          data: {
            endpoint: "https://fcm.googleapis.com/fcm/send/1",
            keys: {
              auth: "private ECDH key",
            },
          }.to_json,
        )

      missing_auth =
        PushSubscription.create!(
          user: user,
          user_auth_token_id:,
          data: {
            endpoint: "https://fcm.googleapis.com/fcm/send/2",
            keys: {
              p256dh: "public ECDH key",
            },
          }.to_json,
        )

      valid_subscription =
        PushSubscription.create!(
          user: user,
          user_auth_token_id:,
          data: {
            endpoint: "https://fcm.googleapis.com/fcm/send/3",
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
          has_entries(
            endpoint: "https://fcm.googleapis.com/fcm/send/3",
            p256dh: "public ECDH key",
            auth: "private ECDH key",
          ),
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

    it "handles DNS lookup failures for endpoints whose domain no longer resolves" do
      WebPush.expects(:payload_send).raises(
        FinalDestination::SSRFDetector::LookupFailedError.new("lookup failed"),
      )
      subscription = create_subscription

      expect { execute_push }.to_not raise_exception

      subscription.reload
      expect(subscription.error_count).to eq(1)
    end

    it "handles endpoints that resolve to disallowed IPs" do
      WebPush.expects(:payload_send).raises(
        FinalDestination::SSRFDetector::DisallowedIpError.new("disallowed"),
      )
      subscription = create_subscription

      expect { execute_push }.to_not raise_exception

      subscription.reload
      expect(subscription.error_count).to eq(1)
    end

    def create_untrusted_subscription(endpoint = "https://push.attacker.test/1")
      PushSubscription.create!(
        user: user,
        user_auth_token_id:,
        data: { endpoint: endpoint, keys: { p256dh: "p256dh", auth: "auth" } }.to_json,
      )
    end

    it "ignores unbound subscriptions when sending trusted pushes or scheduling untrusted pushes" do
      Fabricate(:push_subscription, user: user)
      Fabricate(
        :push_subscription,
        user: user,
        data: {
          endpoint: "https://push.example.org/legacy",
          keys: {
            p256dh: "p256dh",
            auth: "auth",
          },
        }.to_json,
      )
      WebPush.expects(:payload_send).never

      expect_not_enqueued_with(job: :deliver_untrusted_push_notifications) { execute_push }
    end

    it "delivers only to subscriptions whose token still exists and is unexpired" do
      orphan = create_subscription
      expired = Fabricate(:bound_push_subscription, user: user)
      expired.user_auth_token.update!(
        rotated_at: (SiteSetting.maximum_session_age.hours + 1.second).ago,
      )
      live =
        Fabricate(
          :bound_push_subscription,
          user: user,
          data: {
            endpoint: "https://fcm.googleapis.com/fcm/send/live",
            keys: {
              p256dh: "p256dh",
              auth: "auth",
            },
          }.to_json,
        )
      UserAuthToken.where(id: orphan.user_auth_token_id).delete_all
      expect(orphan.reload.user_auth_token_id).to eq(user_auth_token_id)
      delivered = []
      WebPush.stubs(:payload_send).with { |args| delivered << args[:endpoint] }

      execute_push

      expect(delivered).to contain_exactly(live.parsed_data["endpoint"])
    end

    it "delivers to trusted push services inline and defers other hosts to a background job" do
      trusted = create_subscription
      create_untrusted_subscription
      WebPush
        .expects(:payload_send)
        .with(has_entries(endpoint: trusted.parsed_data["endpoint"]))
        .once

      expect_enqueued_with(job: :deliver_untrusted_push_notifications) { execute_push }
    end

    it "delivers only to the newest subscriptions" do
      subscriptions =
        Array.new(PushNotificationPusher::MAX_SUBSCRIPTIONS_PER_USER + 1) do |index|
          PushSubscription.create!(
            user: user,
            user_auth_token_id:,
            data: {
              endpoint: "https://fcm.googleapis.com/fcm/send/#{index}",
              keys: {
                p256dh: "p256dh",
                auth: "auth",
              },
            }.to_json,
          )
        end
      delivered = []
      WebPush.stubs(:payload_send).with { |args| delivered << args[:endpoint] }

      execute_push

      expect(delivered).to match_array(
        subscriptions.drop(1).map { |subscription| subscription.parsed_data["endpoint"] },
      )
    end

    it "passes a total delivery deadline to the push request" do
      create_subscription
      WebPush.expects(:payload_send).with(
        has_entries(total_timeout: PushNotificationPusher::DELIVERY_DEADLINE_SECONDS),
      )

      execute_push
    end

    it "does not count slow deliveries to trusted push services as errors" do
      subscription = create_subscription
      WebPush.stubs(:payload_send)
      PushNotificationPusher.stubs(:monotonic_now).returns(0, 10)

      execute_push

      expect(subscription.reload.error_count).to eq(0)
    end

    describe ".push_untrusted" do
      let(:message) { { title: "title", body: "body", url: "/t/1/2" } }

      it "removes an untrusted subscription after a timeout and a slow delivery" do
        subscription = create_untrusted_subscription
        WebPush.stubs(:payload_send).raises(Net::ReadTimeout.new).then.returns(nil)
        PushNotificationPusher.stubs(:monotonic_now).returns(0, 0, 10)

        PushNotificationPusher.push_untrusted(user, message)
        expect(subscription.reload.error_count).to eq(1)

        PushNotificationPusher.push_untrusted(user, message)
        expect(PushSubscription.exists?(subscription.id)).to eq(false)
      end

      it "delivers to at most two untrusted subscriptions" do
        3.times { |index| create_untrusted_subscription("https://push.attacker.test/#{index}") }
        delivered = []
        WebPush.stubs(:payload_send).with { |args| delivered << args[:endpoint] }

        PushNotificationPusher.push_untrusted(user, message)

        expect(delivered).to contain_exactly(
          "https://push.attacker.test/2",
          "https://push.attacker.test/1",
        )
      end
    end

    describe ".subscribe" do
      def subscribe(endpoint, send_confirmation: "false")
        PushNotificationPusher.subscribe(
          user,
          { endpoint: endpoint, keys: { p256dh: "p256dh", auth: "auth" } },
          send_confirmation,
          user_auth_token_id:,
        )
      end

      it "keeps the newest ten subscriptions with at most two on untrusted hosts" do
        trusted = Array.new(10) { |index| "https://fcm.googleapis.com/fcm/send/#{index}" }
        untrusted = Array.new(3) { |index| "https://push.attacker.test/#{index}" }
        (trusted + untrusted).each { |endpoint| subscribe(endpoint) }

        endpoints =
          user.push_subscriptions.map { |subscription| subscription.parsed_data["endpoint"] }

        expect(endpoints).to match_array(untrusted.last(2) + trusted.last(8))
      end

      it "prunes inactive logins before they can displace a live device under the untrusted cap" do
        live =
          Fabricate(
            :bound_push_subscription,
            user: user,
            data: {
              endpoint: "https://push.example.org/live",
              keys: {
                p256dh: "p256dh",
                auth: "auth",
              },
            }.to_json,
          )
        orphan =
          Fabricate(
            :bound_push_subscription,
            user: user,
            data: live.parsed_data.merge("endpoint" => "https://push.example.org/orphan").to_json,
          )
        expired =
          Fabricate(
            :bound_push_subscription,
            user: user,
            data: live.parsed_data.merge("endpoint" => "https://push.example.org/expired").to_json,
          )
        expired.user_auth_token.update!(
          rotated_at: (SiteSetting.maximum_session_age.hours + 1.second).ago,
        )
        UserAuthToken.where(id: orphan.user_auth_token_id).delete_all
        legacy = Fabricate(:push_subscription, user: user)
        unrelated_orphan =
          Fabricate(:push_subscription, user_auth_token_id: orphan.user_auth_token_id)
        new_endpoint = "https://push.example.org/new"

        subscribe(new_endpoint)

        expect(
          user.push_subscriptions.map { |subscription| subscription.parsed_data["endpoint"] },
        ).to contain_exactly(
          live.parsed_data["endpoint"],
          legacy.parsed_data["endpoint"],
          new_endpoint,
        )
        expect(PushSubscription.exists?(unrelated_orphan.id)).to eq(true)
      end

      it "confirms a new trusted subscription only after commit and only once" do
        endpoint = "https://fcm.googleapis.com/fcm/send/new"
        delivered = []
        WebPush.stubs(:payload_send).with { |args| delivered << args[:endpoint] }

        PushSubscription.transaction(requires_new: true) do
          subscribe(endpoint, send_confirmation: "true")
          expect(delivered).to be_empty
        end
        expect(delivered).to contain_exactly(endpoint)

        subscribe(endpoint, send_confirmation: "true")
        expect(delivered).to contain_exactly(endpoint)
      end

      it "does not confirm a subscription after its login was bulk-deleted" do
        WebPush.expects(:payload_send).never

        PushSubscription.transaction(requires_new: true) do
          subscribe("https://fcm.googleapis.com/fcm/send/new", send_confirmation: "true")
          UserAuthToken.where(id: user_auth_token_id).delete_all
        end

        expect(user.push_subscriptions.sole.user_auth_token_id).to eq(user_auth_token_id)
      end

      it "ignores revoked endpoints on the .invalid TLD" do
        subscribe("https://permanently-removed.invalid/fcm/send/abc", send_confirmation: "true")

        expect(user.push_subscriptions).to be_empty
      end

      it "treats subdomains of configured trusted hosts as trusted" do
        SiteSetting.push_notification_trusted_hosts = "push.example.com"
        3.times { |index| subscribe("https://eu.push.example.com/#{index}") }

        expect(user.push_subscriptions.count).to eq(3)
      end

      it "sends the confirmation for an untrusted subscription from the background job" do
        Jobs.run_immediately!
        WebPush
          .expects(:payload_send)
          .with(has_entries(endpoint: "https://push.attacker.test/1"))
          .once

        subscribe("https://push.attacker.test/1", send_confirmation: "true")
      end
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
