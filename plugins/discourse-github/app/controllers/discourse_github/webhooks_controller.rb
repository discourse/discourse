# frozen_string_literal: true

module DiscourseGithub
  class WebhooksController < ::ApplicationController
    requires_plugin "discourse-github"

    skip_before_action :check_xhr
    skip_before_action :verify_authenticity_token
    skip_before_action :redirect_to_login_if_required

    def github
      return head :forbidden unless verify_signature

      event = request.headers["X-GitHub-Event"]
      return head :ok if %w[pull_request pull_request_review].exclude?(event)

      pr_url = params.dig(:pull_request, :html_url)
      return head :ok if pr_url.blank?

      Jobs.enqueue(:rebake_github_pr_posts, pr_url: pr_url)

      head :ok
    end

    private

    def verify_signature
      secret = SiteSetting.github_webhook_secret
      return false if secret.blank?

      signature = request.headers["X-Hub-Signature-256"]
      return false if signature.blank?

      body = request.body.read
      expected = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", secret, body)

      ActiveSupport::SecurityUtils.secure_compare(expected, signature)
    end
  end
end
