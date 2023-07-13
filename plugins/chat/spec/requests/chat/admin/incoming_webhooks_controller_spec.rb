# frozen_string_literal: true

require "rails_helper"

RSpec.describe Chat::Admin::IncomingWebhooksController do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }
  fab!(:chat_channel1) { Fabricate(:category_channel) }
  fab!(:chat_channel2) { Fabricate(:category_channel) }

  before { SiteSetting.chat_enabled = true }

  describe "#index" do
    fab!(:existing1) { Fabricate(:incoming_chat_webhook) }
    fab!(:existing2) { Fabricate(:incoming_chat_webhook) }

    it "blocks non-admin" do
      sign_in(user)
      get "/admin/plugins/chat.json"
      expect(response.status).to eq(404)
    end

    it "Returns chat_channels and incoming_chat_webhooks for admin" do
      sign_in(admin)
      get "/admin/plugins/chat.json"
      expect(response.status).to eq(200)
      expect(
        response.parsed_body["incoming_chat_webhooks"].map { |webhook| webhook["id"] },
      ).to match_array([existing1.id, existing2.id])
    end
  end

  describe "#create" do
    let(:attrs) { { name: "Test1", chat_channel_id: chat_channel1.id } }

    it "blocks non-admin" do
      sign_in(user)
      post "/admin/plugins/chat/hooks.json", params: attrs
      expect(response.status).to eq(404)
    end

    it "errors when name isn't present" do
      sign_in(admin)
      post "/admin/plugins/chat/hooks.json", params: { chat_channel_id: chat_channel1.id }
      expect(response.status).to eq(400)
    end

    it "errors when chat_channel ID isn't present" do
      sign_in(admin)
      post "/admin/plugins/chat/hooks.json", params: { name: "test1a" }
      expect(response.status).to eq(400)
    end

    it "errors when chat_channel isn't valid" do
      sign_in(admin)
      post "/admin/plugins/chat/hooks.json",
           params: {
             name: "test1a",
             chat_channel_id: Chat::Channel.last.id + 1,
           }
      expect(response.status).to eq(404)
    end

    it "creates a new incoming_chat_webhook record" do
      sign_in(admin)
      expect { post "/admin/plugins/chat/hooks.json", params: attrs }.to change {
        Chat::IncomingWebhook.count
      }.by(1)
      expect(response.parsed_body["name"]).to eq(attrs[:name])
      expect(response.parsed_body["chat_channel"]["id"]).to eq(attrs[:chat_channel_id])
      expect(response.parsed_body["url"]).not_to be_nil
    end
  end

  describe "#update" do
    fab!(:existing) { Fabricate(:incoming_chat_webhook, chat_channel: chat_channel1) }
    let(:attrs) do
      {
        name: "update test",
        chat_channel_id: chat_channel2.id,
        emoji: ":slight_smile:",
        description: "It does stuff!",
        username: "beep boop",
      }
    end

    it "errors for non-admin" do
      sign_in(user)
      put "/admin/plugins/chat/hooks/#{existing.id}.json", params: attrs
      expect(response.status).to eq(404)
    end

    it "errors when name or chat_channel_id aren't present" do
      sign_in(admin)
      invalid_attrs = attrs

      invalid_attrs[:name] = nil
      put "/admin/plugins/chat/hooks/#{existing.id}.json", params: invalid_attrs
      expect(response.status).to eq(400)

      invalid_attrs[:name] = "woopsers"
      invalid_attrs[:chat_channel_id] = nil
      put "/admin/plugins/chat/hooks/#{existing.id}.json", params: invalid_attrs
      expect(response.status).to eq(400)
    end

    it "updates existing incoming_chat_webhook records" do
      sign_in(admin)
      put "/admin/plugins/chat/hooks/#{existing.id}.json", params: attrs
      expect(response.status).to eq(200)
      existing.reload
      expect(existing.name).to eq(attrs[:name])
      expect(existing.description).to eq(attrs[:description])
      expect(existing.emoji).to eq(attrs[:emoji])
      expect(existing.chat_channel_id).to eq(attrs[:chat_channel_id])
      expect(existing.username).to eq(attrs[:username])
    end
  end

  describe "#delete" do
    fab!(:existing) { Fabricate(:incoming_chat_webhook, chat_channel: chat_channel1) }

    it "errors for non-staff" do
      sign_in(user)
      delete "/admin/plugins/chat/hooks/#{existing.id}.json"
      expect(response.status).to eq(404)
    end

    it "destroys incoming_chat_webhook records" do
      sign_in(admin)
      expect { delete "/admin/plugins/chat/hooks/#{existing.id}.json" }.to change {
        Chat::IncomingWebhook.count
      }.by(-1)
    end
  end
end
