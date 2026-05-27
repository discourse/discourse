# frozen_string_literal: true

RSpec.describe CalendarSubscriptionsController do
  fab!(:user)

  describe "#show" do
    it "requires login" do
      get "/calendar-subscriptions.json"
      expect(response.status).to eq(403)
    end

    it "returns has_subscription: false when no key exists" do
      sign_in(user)
      get "/calendar-subscriptions.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["has_subscription"]).to eq(false)
    end

    it "returns has_subscription: true when an active key exists" do
      sign_in(user)
      post "/calendar-subscriptions.json"

      get "/calendar-subscriptions.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["has_subscription"]).to eq(true)
    end

    it "returns available feed names" do
      sign_in(user)
      get "/calendar-subscriptions.json"
      expect(response.parsed_body["feeds"]).to include("bookmarks")
    end
  end

  describe "#create" do
    it "requires login" do
      post "/calendar-subscriptions.json"
      expect(response.status).to eq(403)
    end

    it "creates a key and returns bookmarks URL" do
      sign_in(user)
      post "/calendar-subscriptions.json"
      expect(response.status).to eq(200)

      body = response.parsed_body
      expect(body["key"]).to be_present
      expect(body["urls"]["bookmarks"]).to include("/u/#{user.username_lower}/bookmarks.ics")
      expect(body["urls"]["bookmarks"]).to include("user_api_key=#{body["key"]}")
    end

    it "creates a UserApiKey with bookmarks_calendar scope" do
      sign_in(user)
      post "/calendar-subscriptions.json"

      api_key =
        UserApiKey.joins(:client).find_by(
          user_id: user.id,
          user_api_key_clients: {
            client_id: CalendarSubscriptionsController::CLIENT_ID,
          },
        )
      expect(api_key).to be_present
      expect(api_key.scopes.map(&:name)).to include("bookmarks_calendar")
    end

    it "revokes existing key when creating a new one" do
      sign_in(user)

      post "/calendar-subscriptions.json"
      first_key_hash =
        UserApiKey
          .joins(:client)
          .find_by(
            user_id: user.id,
            user_api_key_clients: {
              client_id: CalendarSubscriptionsController::CLIENT_ID,
            },
          )
          .key_hash

      post "/calendar-subscriptions.json"

      old_key = UserApiKey.find_by(key_hash: first_key_hash)
      expect(old_key.revoked_at).to be_present

      new_key =
        UserApiKey
          .active
          .joins(:client)
          .find_by(
            user_id: user.id,
            user_api_key_clients: {
              client_id: CalendarSubscriptionsController::CLIENT_ID,
            },
          )
      expect(new_key).to be_present
      expect(new_key.key_hash).not_to eq(first_key_hash)
    end

    context "with plugin feeds registered" do
      let(:feed_entry) do
        {
          name: "test_feed",
          scope: "bookmarks_calendar",
          description_key: "test.description",
          url: ->(base_url, _user, key) { "#{base_url}/test.ics?user_api_key=#{key}" },
        }
      end

      let(:plugin) { Plugin::Instance.new }

      before { DiscoursePluginRegistry.register_calendar_subscription_feed(feed_entry, plugin) }

      after do
        DiscoursePluginRegistry._raw_calendar_subscription_feeds.reject! do |h|
          h[:value] == feed_entry
        end
      end

      it "includes plugin feed URLs" do
        sign_in(user)
        post "/calendar-subscriptions.json"

        body = response.parsed_body
        expect(body["urls"]["test_feed"]).to include("/test.ics")
        expect(body["urls"]["bookmarks"]).to be_present
      end
    end

    context "with plugin feeds referencing unregistered scopes" do
      let(:feed_entry) do
        {
          name: "bad_feed",
          scope: "nonexistent_scope",
          description_key: "test.description",
          url: ->(base_url, _user, key) { "#{base_url}/test.ics?user_api_key=#{key}" },
        }
      end

      let(:plugin) { Plugin::Instance.new }

      before { DiscoursePluginRegistry.register_calendar_subscription_feed(feed_entry, plugin) }

      after do
        DiscoursePluginRegistry._raw_calendar_subscription_feeds.reject! do |h|
          h[:value] == feed_entry
        end
      end

      it "skips the unknown scope and still creates the key" do
        sign_in(user)
        post "/calendar-subscriptions.json"
        expect(response.status).to eq(200)

        api_key =
          UserApiKey.joins(:client).find_by(
            user_id: user.id,
            user_api_key_clients: {
              client_id: CalendarSubscriptionsController::CLIENT_ID,
            },
          )
        expect(api_key.scopes.map(&:name)).to eq(["bookmarks_calendar"])
      end
    end
  end

  describe "#destroy" do
    it "requires login" do
      delete "/calendar-subscriptions.json"
      expect(response.status).to eq(403)
    end

    it "revokes the existing subscription key" do
      sign_in(user)
      post "/calendar-subscriptions.json"
      expect(response.status).to eq(200)

      delete "/calendar-subscriptions.json"
      expect(response.status).to eq(204)

      get "/calendar-subscriptions.json"
      expect(response.parsed_body["has_subscription"]).to eq(false)
    end

    it "succeeds even when no key exists" do
      sign_in(user)
      delete "/calendar-subscriptions.json"
      expect(response.status).to eq(204)
    end
  end
end
