# frozen_string_literal: true

RSpec.describe DiscourseZendeskPlugin::Helper do
  subject(:dummy) { Class.new { extend DiscourseZendeskPlugin::Helper } }

  describe ".configured?" do
    it "accepts a complete API token credential pair" do
      SiteSetting.zendesk_jobs_email = "zendesk@example.com"
      SiteSetting.zendesk_jobs_api_token = "legacy-token"

      expect(described_class.configured?).to be(true)
    end

    it "accepts a complete OAuth credential pair" do
      SiteSetting.zendesk_oauth_client_id = "oauth-client-id"
      SiteSetting.zendesk_oauth_client_secret = "oauth-client-secret"

      expect(described_class.configured?).to be(true)
    end

    it "rejects incomplete credential pairs" do
      SiteSetting.zendesk_jobs_email = "zendesk@example.com"
      SiteSetting.zendesk_oauth_client_id = "oauth-client-id"

      expect(described_class.configured?).to be(false)
    end
  end

  describe "#zendesk_client" do
    before { SiteSetting.zendesk_url = "https://your-url.zendesk.com/api/v2" }

    it "uses OAuth when both authentication methods are configured" do
      SiteSetting.zendesk_jobs_email = "zendesk@example.com"
      SiteSetting.zendesk_jobs_api_token = "legacy-token"
      SiteSetting.zendesk_oauth_client_id = "oauth-client-id"
      SiteSetting.zendesk_oauth_client_secret = "oauth-client-secret"
      stub_request(:post, "https://your-url.zendesk.com/oauth/tokens").to_return(
        status: 200,
        body: { access_token: "oauth-access-token", expires_in: 1800 }.to_json,
      )

      client = dummy.zendesk_client

      expect(client.config.access_token).to eq("oauth-access-token")
      expect(client.config.username).to be_nil
      expect(client.config.token).to be_nil
    end

    it "uses legacy authentication while OAuth is incomplete" do
      SiteSetting.zendesk_jobs_email = "zendesk@example.com"
      SiteSetting.zendesk_jobs_api_token = "legacy-token"
      SiteSetting.zendesk_oauth_client_id = "oauth-client-id"

      client = dummy.zendesk_client

      expect(client.config.username).to eq("zendesk@example.com/token")
      expect(client.config.password).to eq("legacy-token")
      expect(client.config.access_token).to be_nil
    end

    it "retries once with a fresh token when Zendesk rejects the cached token" do
      SiteSetting.zendesk_jobs_email = "zendesk@example.com"
      SiteSetting.zendesk_jobs_api_token = "legacy-token"
      SiteSetting.zendesk_oauth_client_id = "oauth-client-id"
      SiteSetting.zendesk_oauth_client_secret = "oauth-client-secret"
      user = Fabricate(:user)
      token_request =
        stub_request(:post, "https://your-url.zendesk.com/oauth/tokens").to_return(
          { status: 200, body: { access_token: "rejected-token", expires_in: 1800 }.to_json },
          { status: 200, body: { access_token: "new-token", expires_in: 1800 }.to_json },
        )
      user_search_request =
        stub_request(
          :get,
          "https://your-url.zendesk.com/api/v2/users/search?query=#{user.email}",
        ).to_return(
          {
            status: 401,
            body: { error: "invalid_token" }.to_json,
            headers: {
              "Content-Type" => "application/json",
            },
          },
          {
            status: 200,
            body: { users: [{ id: 123 }] }.to_json,
            headers: {
              "Content-Type" => "application/json",
            },
          },
        )

      zendesk_user = dummy.fetch_submitter(user)

      expect(zendesk_user.id).to eq(123)
      expect(token_request).to have_been_requested.twice
      expect(user_search_request).to have_been_requested.twice
      expect(WebMock).to have_requested(
        :get,
        "https://your-url.zendesk.com/api/v2/users/search?query=#{user.email}",
      ).with(headers: { "Authorization" => "Bearer rejected-token" }).once
      expect(WebMock).to have_requested(
        :get,
        "https://your-url.zendesk.com/api/v2/users/search?query=#{user.email}",
      ).with(headers: { "Authorization" => "Bearer new-token" }).once
      expect(WebMock).not_to have_requested(:get, %r{/users/search}).with(
        basic_auth: %w[zendesk@example.com/token legacy-token],
      )
    end

    it "raises when Zendesk rejects the replacement token" do
      SiteSetting.zendesk_oauth_client_id = "oauth-client-id"
      SiteSetting.zendesk_oauth_client_secret = "oauth-client-secret"
      user = Fabricate(:user)
      token_request =
        stub_request(:post, "https://your-url.zendesk.com/oauth/tokens").to_return(
          { status: 200, body: { access_token: "first-token", expires_in: 1800 }.to_json },
          { status: 200, body: { access_token: "second-token", expires_in: 1800 }.to_json },
        )
      user_search_request =
        stub_request(
          :get,
          "https://your-url.zendesk.com/api/v2/users/search?query=#{user.email}",
        ).to_return(
          status: 401,
          body: { error: "invalid_token" }.to_json,
          headers: {
            "Content-Type" => "application/json",
          },
        )

      expect { dummy.fetch_submitter(user) }.to raise_error(
        DiscourseZendeskPlugin::InvalidOAuthTokenError,
        "Zendesk rejected the OAuth access token",
      )
      expect(token_request).to have_been_requested.twice
      expect(user_search_request).to have_been_requested.twice
    end
  end

  describe "comment_eligible_for_sync?" do
    subject(:eligible) { dummy.comment_eligible_for_sync?(post) }

    let!(:topic_user) { Fabricate(:user) }
    let!(:other_user) { Fabricate(:user) }
    let(:post_user) { topic_user }
    let!(:topic) { Fabricate(:topic, user: topic_user) }
    let!(:post) { Fabricate(:post, topic: topic, user: post_user) }
    let(:zendesk_job_push_only_author_posts) { true }

    before { SiteSetting.zendesk_job_push_only_author_posts = zendesk_job_push_only_author_posts }

    context "with zendesk_job_push_only_author_posts disabled" do
      let(:zendesk_job_push_only_author_posts) { false }

      context "with same author" do
        it "should be true" do
          expect(eligible).to be_truthy
        end
      end

      context "with different author" do
        let(:post_user) { other_user }
        it "should be true" do
          expect(eligible).to be_truthy
        end
      end
    end

    context "with zendesk_job_push_only_author_posts enabled" do
      let(:zendesk_job_push_only_author_posts) { true }

      context "with same author" do
        it "should be true" do
          expect(eligible).to be_truthy
        end
      end

      context "with different author" do
        let(:post_user) { other_user }
        it "should be false" do
          expect(eligible).to be_falsey
        end
      end
    end
  end
end
