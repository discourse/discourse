# frozen_string_literal: true

RSpec.describe Onebox::Mixins::GithubApi do
  let(:pr_link) { "https://github.com/discourse/discourse/pull/1253" }
  let(:pr_api) { "https://api.github.com/repos/discourse/discourse/pulls/1253" }
  let(:reset_at) { 30.minutes.from_now.to_i }

  def rate_limit_headers(remaining: "0", reset: reset_at, retry_after: nil)
    headers = {
      "x-ratelimit-limit" => "60",
      "x-ratelimit-remaining" => remaining,
      "x-ratelimit-reset" => reset.to_s,
    }
    headers["retry-after"] = retry_after.to_s if retry_after
    headers
  end

  def render_pr
    Onebox::Engine::GithubPullRequestOnebox.new(pr_link).to_html
  rescue OpenURI::HTTPError
    nil
  end

  context "when GitHub returns a primary rate-limit 403" do
    before do
      stub_request(:get, pr_api).to_return(
        status: [403, "Forbidden"],
        headers: rate_limit_headers,
        body: '{"message":"API rate limit exceeded for 1.2.3.4"}',
      )
    end

    it "records a backoff (until x-ratelimit-reset) and skips further GitHub requests" do
      render_pr
      expect(a_request(:get, pr_api)).to have_been_made.once

      ttl = Discourse.redis.without_namespace.ttl("onebox_github_backoff_unauthenticated")
      expect(ttl).to be_between(1, 1800)

      render_pr
      expect(a_request(:get, pr_api)).to have_been_made.once
    end

    it "short-circuits a different GitHub URL/engine sharing the same identity" do
      render_pr

      issue_link = "https://github.com/discourse/discourse/issues/999"
      issue_api = "https://api.github.com/repos/discourse/discourse/issues/999"
      stub_request(:get, issue_api).to_return(status: 200, body: "{}")

      begin
        Onebox::Engine::GithubIssueOnebox.new(issue_link).to_html
      rescue StandardError
        nil
      end
      expect(a_request(:get, issue_api)).not_to have_been_made
    end
  end

  context "when GitHub sends a Retry-After header (secondary rate limit)" do
    before do
      stub_request(:get, pr_api).to_return(
        status: [429, "Too Many Requests"],
        headers: rate_limit_headers(remaining: "42", retry_after: 120),
        body: "{}",
      )
    end

    it "backs off for the Retry-After duration" do
      render_pr
      ttl = Discourse.redis.without_namespace.ttl("onebox_github_backoff_unauthenticated")
      expect(ttl).to be_between(1, 120)
    end
  end

  context "when GitHub returns a 403 that is NOT a rate limit (e.g. private repo)" do
    before do
      stub_request(:get, pr_api).to_return(
        status: [403, "Forbidden"],
        headers: rate_limit_headers(remaining: "57"),
        body: '{"message":"Must have admin rights to Repository."}',
      )
    end

    it "does not back off, so subsequent requests still reach GitHub" do
      render_pr
      expect(
        Discourse.redis.without_namespace.get("onebox_github_backoff_unauthenticated"),
      ).to be_nil

      render_pr
      expect(a_request(:get, pr_api)).to have_been_made.twice
    end
  end

  context "when an org access token is configured" do
    before { SiteSetting.github_onebox_access_tokens = "discourse|gh_token_xyz" }

    it "scopes the backoff per token, not globally" do
      stub_request(:get, pr_api).with(
        headers: {
          "Authorization" => "Bearer gh_token_xyz",
        },
      ).to_return(status: [403, "Forbidden"], headers: rate_limit_headers, body: "{}")

      render_pr

      token_key = "onebox_github_backoff_#{Digest::SHA1.hexdigest("gh_token_xyz")}"
      expect(Discourse.redis.without_namespace.get(token_key)).to be_present
      expect(
        Discourse.redis.without_namespace.get("onebox_github_backoff_unauthenticated"),
      ).to be_nil
    end
  end

  context "when a successful response reports the rate-limit budget is exhausted" do
    before do
      SiteSetting.stubs(:github_pr_status_enabled).returns(false)
      stub_request(:get, pr_api).to_return(
        status: 200,
        headers: rate_limit_headers(remaining: "0"),
        body: onebox_response("githubpullrequest"),
      )
    end

    it "proactively backs off until reset, without waiting for a 403" do
      render_pr
      ttl = Discourse.redis.without_namespace.ttl("onebox_github_backoff_unauthenticated")
      expect(ttl).to be_between(1, 1800)

      WebMock::RequestRegistry.instance.reset!
      render_pr
      expect(a_request(:get, pr_api)).not_to have_been_made
    end
  end

  context "when any GitHub API engine hits the rate limit on its primary fetch" do
    before do
      stub_request(:get, /api\.github\.com/).to_return(
        status: [403, "Forbidden"],
        headers: rate_limit_headers,
        body: "{}",
      )
    end

    [
      ["pull request", Onebox::Engine::GithubPullRequestOnebox, "https://github.com/d/d/pull/1"],
      ["commit", Onebox::Engine::GithubCommitOnebox, "https://github.com/d/d/commit/#{"a" * 40}"],
      ["issue", Onebox::Engine::GithubIssueOnebox, "https://github.com/d/d/issues/1"],
      ["repo", Onebox::Engine::GithubRepoOnebox, "https://github.com/d/d"],
      ["actions", Onebox::Engine::GithubActionsOnebox, "https://github.com/d/d/actions/runs/1"],
      ["gist", Onebox::Engine::GithubGistOnebox, "https://gist.github.com/d/abc123def456"],
    ].each do |name, klass, link|
      it "records a backoff when the #{name} engine is rate-limited" do
        begin
          klass.new(link).to_html
        rescue StandardError
          nil
        end
        expect(
          Discourse.redis.without_namespace.get("onebox_github_backoff_unauthenticated"),
        ).to be_present
      end
    end
  end

  context "when a default access token is configured" do
    it "authenticates gist API calls with the default token" do
      SiteSetting.github_onebox_access_tokens = "default|gh_default_token"
      stub =
        stub_request(:get, "https://api.github.com/gists/abc123def456").with(
          headers: {
            "Authorization" => "Bearer gh_default_token",
          },
        ).to_return(status: 200, body: '{"files":{}}')

      Onebox::Engine::GithubGistOnebox.new("https://gist.github.com/d/abc123def456").to_html

      expect(stub).to have_been_requested
    end
  end
end
