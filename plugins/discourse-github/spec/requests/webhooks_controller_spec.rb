# frozen_string_literal: true

RSpec.describe DiscourseGithub::WebhooksController do
  let(:webhook_secret) { "test_secret_123" }
  let(:pr_url) { "https://github.com/discourse/discourse/pull/123" }

  let(:pull_request_payload) do
    { action: "closed", pull_request: { html_url: pr_url, merged: true } }
  end

  let(:pull_request_review_payload) do
    { action: "submitted", review: { state: "approved" }, pull_request: { html_url: pr_url } }
  end

  def sign_payload(payload, secret)
    body = payload.to_json
    signature = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", secret, body)
    [body, signature]
  end

  before do
    SiteSetting.enable_discourse_github_plugin = true
    SiteSetting.github_webhook_secret = webhook_secret
  end

  describe "#github" do
    context "when plugin is disabled" do
      before { SiteSetting.enable_discourse_github_plugin = false }

      it "returns 404" do
        body, signature = sign_payload(pull_request_payload, webhook_secret)
        post "/discourse-github/webhooks/github",
             params: body,
             headers: {
               "CONTENT_TYPE" => "application/json",
               "X-GitHub-Event" => "pull_request",
               "X-Hub-Signature-256" => signature,
             }
        expect(response.status).to eq(404)
      end
    end

    context "with invalid signature" do
      it "returns 403" do
        body, _signature = sign_payload(pull_request_payload, webhook_secret)
        post "/discourse-github/webhooks/github",
             params: body,
             headers: {
               "CONTENT_TYPE" => "application/json",
               "X-GitHub-Event" => "pull_request",
               "X-Hub-Signature-256" => "sha256=invalid",
             }
        expect(response.status).to eq(403)
      end
    end

    context "with missing signature" do
      it "returns 403" do
        post "/discourse-github/webhooks/github",
             params: pull_request_payload.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
               "X-GitHub-Event" => "pull_request",
             }
        expect(response.status).to eq(403)
      end
    end

    context "with missing webhook secret setting" do
      before { SiteSetting.github_webhook_secret = "" }

      it "returns 403" do
        body, signature = sign_payload(pull_request_payload, webhook_secret)
        post "/discourse-github/webhooks/github",
             params: body,
             headers: {
               "CONTENT_TYPE" => "application/json",
               "X-GitHub-Event" => "pull_request",
               "X-Hub-Signature-256" => signature,
             }
        expect(response.status).to eq(403)
      end
    end

    context "with valid signature" do
      it "enqueues rebake job for pull_request event" do
        body, signature = sign_payload(pull_request_payload, webhook_secret)

        expect_enqueued_with(job: :rebake_github_pr_posts, args: { pr_url: pr_url }) do
          post "/discourse-github/webhooks/github",
               params: body,
               headers: {
                 "CONTENT_TYPE" => "application/json",
                 "X-GitHub-Event" => "pull_request",
                 "X-Hub-Signature-256" => signature,
               }
        end

        expect(response.status).to eq(200)
      end

      it "enqueues rebake job for pull_request_review event" do
        body, signature = sign_payload(pull_request_review_payload, webhook_secret)

        expect_enqueued_with(job: :rebake_github_pr_posts, args: { pr_url: pr_url }) do
          post "/discourse-github/webhooks/github",
               params: body,
               headers: {
                 "CONTENT_TYPE" => "application/json",
                 "X-GitHub-Event" => "pull_request_review",
                 "X-Hub-Signature-256" => signature,
               }
        end

        expect(response.status).to eq(200)
      end

      it "ignores other event types" do
        payload = { action: "created", issue: { html_url: "https://github.com/org/repo/issues/1" } }
        body, signature = sign_payload(payload, webhook_secret)

        post "/discourse-github/webhooks/github",
             params: body,
             headers: {
               "CONTENT_TYPE" => "application/json",
               "X-GitHub-Event" => "issues",
               "X-Hub-Signature-256" => signature,
             }

        expect(response.status).to eq(200)
        expect(Jobs::RebakeGithubPrPosts.jobs.size).to eq(0)
      end

      it "handles missing PR URL gracefully" do
        payload = { action: "closed", pull_request: {} }
        body, signature = sign_payload(payload, webhook_secret)

        post "/discourse-github/webhooks/github",
             params: body,
             headers: {
               "CONTENT_TYPE" => "application/json",
               "X-GitHub-Event" => "pull_request",
               "X-Hub-Signature-256" => signature,
             }

        expect(response.status).to eq(200)
        expect(Jobs::RebakeGithubPrPosts.jobs.size).to eq(0)
      end
    end
  end
end
