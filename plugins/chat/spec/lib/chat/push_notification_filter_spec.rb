# frozen_string_literal: true

RSpec.describe PostAlerter do
  fab!(:user)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.allowed_user_api_push_urls = "https://site2.com/push"

    2.times do |i|
      client = Fabricate(:user_api_key_client, client_id: "xxx#{i}", application_name: "iPhone#{i}")
      Fabricate(
        :user_api_key,
        user: user,
        scopes: ["notifications"].map { |name| UserApiKeyScope.new(name: name) },
        push_url: "https://site2.com/push",
        user_api_key_client_id: client.id,
      )
    end
  end

  def push(notification_type)
    PostAlerter.push_notification(
      user,
      {
        notification_type: notification_type,
        post_number: 1,
        topic_id: topic.id,
        post_id: post.id,
        excerpt: "excerpt",
        username: "someone",
      },
    )
  end

  context "when push_notification_level is chat_only" do
    before { user.user_option.update!(push_notification_level: :chat_only) }

    it "suppresses non-chat push notifications" do
      expect { push(Notification.types[:mentioned]) }.not_to change {
        Jobs::DeliverPushNotification.jobs.count
      }
    end

    it "still delivers chat push notifications" do
      expect { push(Notification.types[:chat_mention]) }.to change {
        Jobs::DeliverPushNotification.jobs.count
      }.by(1)
    end

    context "when the user has disabled chat" do
      before { user.user_option.update!(chat_enabled: false) }

      it "delivers all push notifications" do
        expect { push(Notification.types[:mentioned]) }.to change {
          Jobs::DeliverPushNotification.jobs.count
        }.by(1)
      end
    end

    context "when chat is disabled site-wide" do
      before { SiteSetting.chat_enabled = false }

      it "delivers all push notifications" do
        expect { push(Notification.types[:mentioned]) }.to change {
          Jobs::DeliverPushNotification.jobs.count
        }.by(1)
      end
    end
  end

  context "when push_notification_level is all" do
    before { user.user_option.update!(push_notification_level: :all) }

    it "delivers non-chat push notifications" do
      expect { push(Notification.types[:mentioned]) }.to change {
        Jobs::DeliverPushNotification.jobs.count
      }.by(1)
    end
  end
end
