# frozen_string_literal: true

RSpec.describe DiscourseZendeskPlugin::SyncController do
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:webhook_user, :user)

  describe "#webhook" do
    let(:token) { "secret-token" }
    let(:ticket_id) { 12 }
    let(:zendesk_url_default) { "https://your-url.zendesk.com/api/v2" }
    let(:default_header) { { "Content-Type" => "application/json; charset=UTF-8" } }
    let(:comment_id) { 321 }
    let(:comment_body) { "trusted zendesk comment" }
    let(:comment_response) do
      { comments: [{ id: comment_id, body: comment_body, public: true }] }.to_json
    end

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
      put "/zendesk-plugin/sync.json",
          params: {
            token: token,
            topic_id: topic.id,
            ticket_id: ticket_id,
          }
      expect(response.status).to eq(400)
    end

    it "attributes the synced comment to the authenticated webhook email" do
      SiteSetting.zendesk_autogenerate_categories = category.id.to_s
      stub_request(:get, "#{zendesk_url_default}/tickets/#{ticket_id}/comments").to_return(
        status: 200,
        body: comment_response,
        headers: default_header,
      )

      expect {
        put "/zendesk-plugin/sync.json",
            params: {
              token: token,
              topic_id: topic.id,
              ticket_id: ticket_id,
              email: webhook_user.email,
            }
      }.to change { topic.reload.posts.count }.by(1)

      expect(response.status).to eq(204)
      expect(response.body).to be_blank
      expect(topic.reload.posts.last.raw).to eq(comment_body)
      expect(topic.posts.last.user).to eq(webhook_user)
    end
  end
end
