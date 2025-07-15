# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseZendeskPlugin::SyncController do
  describe "#webhook" do
    let!(:token) { "secret-token" }
    let!(:topic) { Fabricate(:topic) }

    before do
      SiteSetting.zendesk_enabled = true
      SiteSetting.sync_comments_from_zendesk = true
      SiteSetting.zendesk_incoming_webhook_token = token
    end

    it "raises an error when the token is missing" do
      put "/zendesk-plugin/sync.json"
      expect(response.status).to eq(400)
    end

    it "raises an error when the token is invalid" do
      put "/zendesk-plugin/sync.json", params: { token: "token" }
      expect(response.status).to eq(403)
    end

    it "raises an error if the plugin is disabled" do
      SiteSetting.zendesk_enabled = false
      put "/zendesk-plugin/sync.json", params: { token: token }
      expect(response.status).to eq(404)
    end

    it "raises an error if `sync_comments_from_zendesk` is disabled" do
      SiteSetting.sync_comments_from_zendesk = false
      put "/zendesk-plugin/sync.json", params: { token: token }
      expect(response.status).to eq(422)
    end

    it "raises an error if required parameters are missing" do
      put "/zendesk-plugin/sync.json", params: { token: token, topic_id: topic.id }
      expect(response.status).to eq(400)
    end

    it "raises an error when topic is not present" do
      topic.destroy!
      put "/zendesk-plugin/sync.json", params: { token: token, topic_id: topic.id, ticket_id: 12 }
      expect(response.status).to eq(400)
    end

    it "returns 204 when the request succeeds" do
      put "/zendesk-plugin/sync.json", params: { token: token, topic_id: topic.id, ticket_id: 12 }
      expect(response.status).to eq(204)
    end
  end
end
