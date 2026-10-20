# frozen_string_literal: true

RSpec.describe Jobs::DeliverPushNotification do
  fab!(:user)
  fab!(:post)

  let(:payload) do
    {
      "notification_type" => 1,
      "post_url" => "/t/#{post.topic_id}/#{post.post_number}",
      "excerpt" => "Hello you",
    }
  end

  before do
    freeze_time
    SiteSetting.push_notification_time_window_mins = 5
  end

  describe "time window gate" do
    fab!(:time_window_push_subscription) { Fabricate(:push_subscription, user: user) }

    it "does not deliver when user is missing" do
      PushNotificationPusher.expects(:push).never
      HubPushNotificationPusher.expects(:push).never
      Jobs::DeliverPushNotification.new.execute(user_id: -999, payload: payload)
    end

    it "does not deliver when user was recently seen" do
      user.update!(last_seen_at: 1.minute.ago)
      PushNotificationPusher.expects(:push).never
      HubPushNotificationPusher.expects(:push).never
      Jobs::DeliverPushNotification.new.execute(user_id: user.id, payload: payload)
    end

    it "delivers when user is offline" do
      user.update!(last_seen_at: 10.minutes.ago)
      PushNotificationPusher.expects(:push).with(user, payload)
      HubPushNotificationPusher.expects(:push).with(user, payload)
      Jobs::DeliverPushNotification.new.execute(user_id: user.id, payload: payload)
    end

    it "delivers when bypass_time_window is true despite user being active" do
      user.update!(last_seen_at: 1.minute.ago)
      PushNotificationPusher.expects(:push).with(user, payload)
      HubPushNotificationPusher.expects(:push).with(user, payload)

      Jobs::DeliverPushNotification.new.execute(
        user_id: user.id,
        bypass_time_window: true,
        payload: payload,
      )
    end
  end

  describe "web push delivery" do
    before { user.update!(last_seen_at: 10.minutes.ago) }

    it "calls PushNotificationPusher when user has push subscriptions" do
      Fabricate(:push_subscription, user: user)
      PushNotificationPusher.expects(:push).with(user, payload).once
      Jobs::DeliverPushNotification.new.execute(user_id: user.id, payload: payload)
    end

    it "does not call PushNotificationPusher when user has no push subscriptions" do
      PushNotificationPusher.expects(:push).never
      Jobs::DeliverPushNotification.new.execute(user_id: user.id, payload: payload)
    end
  end

  describe "hub push delivery" do
    before { user.update!(last_seen_at: 10.minutes.ago) }

    it "calls HubPushNotificationPusher" do
      HubPushNotificationPusher.expects(:push).with(user, payload).once
      Jobs::DeliverPushNotification.new.execute(user_id: user.id, payload: payload)
    end
  end

  describe "both mechanisms" do
    it "delivers via both pushers for the same user" do
      user.update!(last_seen_at: 10.minutes.ago)
      Fabricate(:push_subscription, user: user)

      PushNotificationPusher.expects(:push).with(user, payload).once
      HubPushNotificationPusher.expects(:push).with(user, payload).once

      Jobs::DeliverPushNotification.new.execute(user_id: user.id, payload: payload)
    end
  end

  describe "content localization" do
    fab!(:topic) { Fabricate(:topic, title: "Original topic title", locale: "en") }
    fab!(:localized_post) do
      Fabricate(:post, topic: topic, raw: "Original post content", locale: "en")
    end

    let(:localizable_payload) do
      {
        "notification_type" => 1,
        "post_url" => "/t/#{topic.id}/#{localized_post.post_number}",
        "topic_title" => topic.title,
        "topic_id" => topic.id,
        "post_id" => localized_post.id,
        "excerpt" => "Original post content",
        "username" => "system",
        "post_number" => localized_post.post_number,
      }
    end

    before do
      SiteSetting.content_localization_enabled = true
      SiteSetting.allow_user_locale = true
      user.update!(last_seen_at: 10.minutes.ago, locale: "ja")
    end

    it "localizes payload before delivering to web push" do
      Fabricate(:push_subscription, user: user)
      Fabricate(
        :topic_localization,
        topic: topic,
        locale: "ja",
        title: "ローカライズされたトピック",
        fancy_title: "ローカライズされたトピック",
      )
      Fabricate(
        :post_localization,
        post: localized_post,
        locale: "ja",
        raw: "ローカライズされた投稿",
        cooked: "<p>ローカライズされた投稿</p>",
      )

      PushNotificationPusher
        .expects(:push)
        .with { |u, p| p[:topic_title] == "ローカライズされたトピック" && p[:excerpt] == "ローカライズされた投稿" }
        .once

      Jobs::DeliverPushNotification.new.execute(user_id: user.id, payload: localizable_payload)
    end

    it "localizes payload before delivering to hub push" do
      SiteSetting.allowed_user_api_push_urls = "https://hub.example.com/push"
      client = Fabricate(:user_api_key_client)
      Fabricate(
        :user_api_key,
        user: user,
        scopes: ["notifications"].map { |name| UserApiKeyScope.new(name: name) },
        push_url: "https://hub.example.com/push",
        user_api_key_client_id: client.id,
      )
      Fabricate(
        :topic_localization,
        topic: topic,
        locale: "ja",
        title: "ローカライズされたトピック",
        fancy_title: "ローカライズされたトピック",
      )

      body = nil
      stub_request(:post, "https://hub.example.com/push").to_return do |request|
        body = JSON.parse(request.body)
        { status: 200 }
      end

      Jobs::DeliverPushNotification.new.execute(user_id: user.id, payload: localizable_payload)

      expect(body["notifications"].first["topic_title"]).to eq("ローカライズされたトピック")
    end

    it "does not localize when content_localization_enabled is false" do
      SiteSetting.content_localization_enabled = false
      Fabricate(:push_subscription, user: user)
      Fabricate(
        :topic_localization,
        topic: topic,
        locale: "ja",
        title: "ローカライズされたトピック",
        fancy_title: "ローカライズされたトピック",
      )

      PushNotificationPusher
        .expects(:push)
        .with do |u, p|
          p[:topic_title] == "Original topic title" || p["topic_title"] == "Original topic title"
        end
        .once

      Jobs::DeliverPushNotification.new.execute(user_id: user.id, payload: localizable_payload)
    end

    it "keeps the original excerpt when the translation is for an older version of the post" do
      Fabricate(:push_subscription, user: user)
      Fabricate(
        :post_localization,
        post: localized_post,
        locale: "ja",
        post_version: localized_post.version - 1,
        cooked: "<p>古い翻訳</p>",
      )

      PushNotificationPusher.expects(:push).with { |_, p| p[:excerpt] == "Original post content" }

      Jobs::DeliverPushNotification.new.execute(user_id: user.id, payload: localizable_payload)
    end

    it "keeps the original content when the user turned off automatic translation" do
      user.user_option.update!(automatically_translate: false)
      Fabricate(:push_subscription, user: user)
      Fabricate(:post_localization, post: localized_post, locale: "ja", cooked: "<p>翻訳</p>")

      PushNotificationPusher.expects(:push).with { |_, p| p[:excerpt] == "Original post content" }

      Jobs::DeliverPushNotification.new.execute(user_id: user.id, payload: localizable_payload)
    end

    it "keeps a caller-provided excerpt" do
      Fabricate(:push_subscription, user: user)
      Fabricate(:topic_localization, topic: topic, locale: "ja", title: "ローカライズされたトピック")
      Fabricate(:post_localization, post: localized_post, locale: "ja", cooked: "<p>翻訳</p>")

      PushNotificationPusher
        .expects(:push)
        .with do |_, p|
          p[:topic_title] == "ローカライズされたトピック" && p[:excerpt] == "Original post content"
        end

      Jobs::DeliverPushNotification.new.execute(
        user_id: user.id,
        payload: localizable_payload,
        keep_excerpt: true,
      )
    end

    describe "when a translation is still pending" do
      let(:plugin) { Plugin::Instance.new }
      let(:pending) { [true] }
      let(:pending_modifier) { Proc.new { |_pending, _post, _user| pending.first } }

      before do
        Fabricate(:push_subscription, user: user)
        DiscoursePluginRegistry.register_modifier(
          plugin,
          :deliver_push_notification_localization_pending,
          &pending_modifier
        )
      end

      after do
        DiscoursePluginRegistry.unregister_modifier(
          plugin,
          :deliver_push_notification_localization_pending,
          &pending_modifier
        )
      end

      def deliver(**args)
        Jobs::DeliverPushNotification.new.execute(
          user_id: user.id,
          payload: localizable_payload,
          **args,
        )
      end

      def held_token
        Jobs::DeliverPushNotification.jobs.last.dig("args", 0, "localization_wait_token")
      end

      it "holds the push until the wait limit at most" do
        SiteSetting.push_notification_localization_max_wait_mins = 3
        PushNotificationPusher.expects(:push).never

        expect_enqueued_with(job: :deliver_push_notification, at: 3.minutes.from_now) { deliver }
        expect(held_token).to be_present
      end

      it "sends the held push once it is released by a stored translation" do
        PushNotificationPusher.expects(:push).with { |_, p| p[:excerpt] == "ローカライズされた投稿" }.once

        deliver
        token = held_token
        Jobs::DeliverPushNotification.jobs.clear

        pending[0] = false
        Fabricate(
          :post_localization,
          post: localized_post,
          locale: "ja",
          cooked: "<p>ローカライズされた投稿</p>",
        )

        released = Jobs::DeliverPushNotification.jobs.map { |job| job["args"].first }
        expect(released.map { |a| a["localization_wait_token"] }).to eq([token])

        # The release and the wait limit both deliver the held push; only one sends it.
        2.times { deliver(localization_wait_token: token) }
      end

      it "still sends a held push whose wait state has expired" do
        deliver
        token = held_token
        Discourse.redis.del("push_notification_localization_wait:#{localized_post.id}")

        PushNotificationPusher.expects(:push).once

        deliver(localization_wait_token: token)
      end

      it "lets another delivery send a held push when one fails" do
        deliver
        token = held_token

        PushNotificationPusher.stubs(:push).raises(StandardError).then.returns(nil)

        expect { deliver(localization_wait_token: token) }.to raise_error(StandardError)

        PushNotificationPusher.expects(:push).once
        deliver(localization_wait_token: token)
      end

      it "sends the held push at the wait limit even when the translation never came" do
        deliver
        token = held_token

        PushNotificationPusher.expects(:push).with { |_, p| p[:excerpt] == "Original post content" }

        deliver(localization_wait_token: token)
      end

      it "does not leave a held push behind for its retry to duplicate when holding fails" do
        Post.any_instance.stubs(:reload).raises(ActiveRecord::ConnectionNotEstablished)
        PushNotificationPusher.expects(:push).never

        expect { deliver }.to raise_error(ActiveRecord::ConnectionNotEstablished)

        deliver(localization_wait_token: held_token)
      end

      it "does not release pushes held for other locales" do
        deliver
        Jobs::DeliverPushNotification.jobs.clear

        Fabricate(:post_localization, post: localized_post, locale: "de")

        expect(Jobs::DeliverPushNotification.jobs).to be_empty
      end

      it "releases every held push when the translator is done with the post" do
        deliver
        token = held_token
        Jobs::DeliverPushNotification.jobs.clear

        DiscourseEvent.trigger(:post_localizations_finished, localized_post.id)

        released = Jobs::DeliverPushNotification.jobs.map { |job| job["args"].first }
        expect(released.map { |a| a["localization_wait_token"] }).to eq([token])
      end

      it "does not hold the push once the translator is done with the post" do
        PushNotificationLocalizationWait.finish(localized_post.id)
        PushNotificationPusher.expects(:push).once

        expect_not_enqueued_with(job: :deliver_push_notification) { deliver }
      end

      it "sends right away when the translation was stored while holding the push" do
        PushNotificationLocalizationWait
          .stubs(:hold)
          .with do
            pending[0] = false
            true
          end
          .returns("token")
        PushNotificationLocalizationWait
          .expects(:claim)
          .with(localized_post.id, "token")
          .returns(true)
        PushNotificationPusher.expects(:push).once

        deliver
      end

      it "does not wait when the wait limit is 0" do
        SiteSetting.push_notification_localization_max_wait_mins = 0
        PushNotificationPusher.expects(:push).once

        expect_not_enqueued_with(job: :deliver_push_notification) { deliver }
      end

      it "does not wait when the user understands the language of the post" do
        user.user_option.update!(understood_languages: ["en"])
        PushNotificationPusher.expects(:push).once

        expect_not_enqueued_with(job: :deliver_push_notification) { deliver }
      end
    end
  end
end
