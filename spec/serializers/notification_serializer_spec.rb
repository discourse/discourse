# frozen_string_literal: true

RSpec.describe NotificationSerializer do
  describe "#as_json" do
    fab!(:user)
    let(:notification) { Fabricate(:notification, user: user) }
    let(:serializer) { NotificationSerializer.new(notification) }
    let(:json) { serializer.as_json }

    it "returns the user_id" do
      expect(json[:notification][:user_id]).to eq(user.id)
    end

    it "generates a fallback slug without writing it to the topic" do
      topic = Fabricate(:topic, title: "A topic with a missing slug")
      topic.update_column(:slug, nil)
      notification.update!(topic: topic)

      expect(json[:notification][:slug]).to eq("a-topic-with-a-missing-slug")
      expect(topic.reload[:slug]).to be_nil
    end

    it "does not include external_id when sso is disabled" do
      expect(json[:notification].key?(:external_id)).to eq(false)
    end

    it "removes name fields from notification data when names are disabled" do
      SiteSetting.enable_names = false
      notification.update!(
        data: {
          display_name: "Display Name",
          name: "Name",
          name2: "Second Name",
          original_name: "Original Name",
          safe_key: "safe value",
        }.to_json,
      )

      expect(json[:notification][:data]).to eq("safe_key" => "safe value")
    end

    it "hydrates usernames and full names from stored user IDs and reflects renames" do
      SiteSetting.enable_names = true
      actor1 = Fabricate(:user, username: "alice", name: "Alice One")
      actor2 = Fabricate(:user, username: "carol", name: "Carol Two")
      notification.update!(
        data: {
          acting_user_id: actor1.id,
          display_user_id: actor1.id,
          original_user_id: actor1.id,
          user2_id: actor2.id,
          mentioned_by_user_id: actor1.id,
          invited_by_user_id: actor2.id,
          display_name: "Stale Name",
          original_name: "Stale Original Name",
          name: "Stale User Name",
          name2: "Stale User2 Name",
          username: actor1.username,
        }.to_json,
      )

      expect(JSON.parse(notification.reload.data)).to eq(
        "acting_user_id" => actor1.id,
        "display_user_id" => actor1.id,
        "original_user_id" => actor1.id,
        "user2_id" => actor2.id,
        "mentioned_by_user_id" => actor1.id,
        "invited_by_user_id" => actor2.id,
      )

      serialized = NotificationSerializer.new(notification).as_json[:notification][:data]
      expect(serialized).to eq(
        "acting_user_id" => actor1.id,
        "display_user_id" => actor1.id,
        "original_user_id" => actor1.id,
        "user2_id" => actor2.id,
        "mentioned_by_user_id" => actor1.id,
        "invited_by_user_id" => actor2.id,
        "username" => "alice",
        "name" => "Alice One",
        "display_username" => "alice",
        "display_name" => "Alice One",
        "original_username" => "alice",
        "original_name" => "Alice One",
        "username2" => "carol",
        "name2" => "Carol Two",
        "mentioned_by_username" => "alice",
        "invited_by_username" => "carol",
      )

      actor1.update!(username: "alice_new", name: nil)
      updated_serialized =
        NotificationSerializer.new(Notification.find(notification.id)).as_json[:notification][:data]
      expect(updated_serialized).to eq(
        "acting_user_id" => actor1.id,
        "display_user_id" => actor1.id,
        "original_user_id" => actor1.id,
        "user2_id" => actor2.id,
        "mentioned_by_user_id" => actor1.id,
        "invited_by_user_id" => actor2.id,
        "username" => "alice_new",
        "display_username" => "alice_new",
        "original_username" => "alice_new",
        "username2" => "carol",
        "name2" => "Carol Two",
        "mentioned_by_username" => "alice_new",
        "invited_by_username" => "carol",
      )

      notification.update!(data: { display_user_id: actor2.id }.to_json)
      expect(NotificationSerializer.new(notification).as_json[:notification][:data]).to eq(
        "display_user_id" => actor2.id,
        "display_username" => "carol",
        "display_name" => "Carol Two",
      )
    end

    it "hydrates display_label as display_username without storing display_username" do
      actor = Fabricate(:user, username: "alice", name: "Alice One")
      notification.update!(data: { original_user_id: actor.id, display_label: "2 replies" }.to_json)

      serialized = NotificationSerializer.new(notification).as_json[:notification][:data]
      expect(serialized["display_username"]).to eq("2 replies")
      expect(serialized).not_to have_key("display_label")
      expect(serialized["original_username"]).to eq("alice")
    end
  end

  describe "#sso_enabled" do
    let :user do
      user = Fabricate(:user)
      SingleSignOnRecord.create!(user_id: user.id, external_id: "12345", last_payload: "")
      user
    end
    let(:notification) { Fabricate(:notification, user: user) }
    let(:serializer) { NotificationSerializer.new(notification) }
    let(:json) { serializer.as_json }

    it "includes the external ID" do
      SiteSetting.discourse_connect_url = "http://example.com/discourse_sso"
      SiteSetting.discourse_connect_secret = "12345678910"
      SiteSetting.enable_discourse_connect = true
      expect(json[:notification][:external_id]).to eq("12345")
    end
  end

  describe "localizations" do
    fab!(:topic) { Fabricate(:topic, locale: "ja") }
    fab!(:user)

    before { I18n.locale = "ja" }

    it "returns the locale if there is a topic" do
      SiteSetting.content_localization_enabled = true

      notification = Fabricate(:notification, user:, topic:)
      serializer = NotificationSerializer.new(notification)
      json = serializer.as_json
      expect(json[:notification][:locale]).to eq("ja")
    end

    it "skips locale if there is no topic" do
      SiteSetting.content_localization_enabled = true

      notification = Fabricate(:notification, user:)
      serializer = NotificationSerializer.new(notification)
      json = serializer.as_json
      expect(json[:notification][:locale]).to eq(nil)
    end
  end
end
