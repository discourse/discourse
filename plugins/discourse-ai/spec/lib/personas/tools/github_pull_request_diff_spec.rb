# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::Personas::Tools::GithubPullRequestDiff do
  let(:bot_user) { Fabricate(:user) }
  fab!(:llm_model)
  let(:llm) { DiscourseAi::Completions::Llm.proxy("custom:#{llm_model.id}") }
  let(:tool) { described_class.new({ repo: repo, pull_id: pull_id }, bot_user: bot_user, llm: llm) }

  before { enable_current_plugin }

  context "with #sort_and_shorten_diff" do
    it "sorts and shortens the diff without dropping data" do
      diff = <<~DIFF
      diff --git a/src/lib.rs b/src/lib.rs
      index b466edd..66b068f 100644
      --- a/src/lib.rs
      +++ b/src/lib.rs
      this is a longer diff
      this is a longer diff
      this is a longer diff
      diff --git a/tests/test_encoding.py b/tests/test_encoding.py
      index 27b2192..9f31319 100644
      --- a/tests/test_encoding.py
      +++ b/tests/test_encoding.py
      short diff
      DIFF

      sorted_diff = described_class.sort_and_shorten_diff(diff)

      expect(sorted_diff).to eq(<<~DIFF)
      diff --git a/tests/test_encoding.py b/tests/test_encoding.py
      index 27b2192..9f31319 100644
      --- a/tests/test_encoding.py
      +++ b/tests/test_encoding.py
      short diff

      diff --git a/src/lib.rs b/src/lib.rs
      index b466edd..66b068f 100644
      --- a/src/lib.rs
      +++ b/src/lib.rs
      this is a longer diff
      this is a longer diff
      this is a longer diff
      DIFF
    end
  end

  context "with a valid pull request" do
    let(:repo) { "discourse/discourse-automation" }
    let(:pull_id) { 253 }
    let(:diff) { <<~DIFF }
      diff --git a/lib/discourse_automation/automation.rb b/lib/discourse_automation/automation.rb
      index 3e3e3e3..4f4f4f4 100644
      --- a/lib/discourse_automation/automation.rb
      +++ b/lib/discourse_automation/automation.rb
      @@ -1,3 +1,3 @@
      -module DiscourseAutomation
    DIFF

    let(:pr_info) do
      {
        "title" => "Test PR",
        "state" => "open",
        "user" => {
          "login" => "test-user",
        },
        "created_at" => "2023-01-01T00:00:00Z",
        "updated_at" => "2023-01-02T00:00:00Z",
        "head" => {
          "repo" => {
            "full_name" => "test/repo",
          },
          "ref" => "feature-branch",
          "sha" => "abc123",
        },
        "base" => {
          "repo" => {
            "full_name" => "main/repo",
          },
          "ref" => "main",
        },
      }
    end

    it "retrieves both PR info and diff" do
      stub_request(:get, "https://api.github.com/repos/#{repo}/pulls/#{pull_id}").with(
        headers: {
          "Accept" => "application/json",
          "User-Agent" => DiscourseAi::AiBot::USER_AGENT,
        },
      ).to_return(status: 200, body: pr_info.to_json)

      stub_request(:get, "https://api.github.com/repos/#{repo}/pulls/#{pull_id}").with(
        headers: {
          "Accept" => "application/vnd.github.v3.diff",
          "User-Agent" => DiscourseAi::AiBot::USER_AGENT,
        },
      ).to_return(status: 200, body: diff)

      result = tool.invoke
      expect(result[:diff]).to eq(diff)
      expect(result[:pr_info]).to include(title: "Test PR", state: "open", author: "test-user")
      expect(result[:error]).to be_nil
    end

    it "uses the github access token if present" do
      SiteSetting.ai_bot_github_access_token = "ABC"

      stub_request(:get, "https://api.github.com/repos/#{repo}/pulls/#{pull_id}").with(
        headers: {
          "Accept" => "application/json",
          "User-Agent" => DiscourseAi::AiBot::USER_AGENT,
          "Authorization" => "Bearer ABC",
        },
      ).to_return(status: 200, body: pr_info.to_json)

      stub_request(:get, "https://api.github.com/repos/#{repo}/pulls/#{pull_id}").with(
        headers: {
          "Accept" => "application/vnd.github.v3.diff",
          "User-Agent" => DiscourseAi::AiBot::USER_AGENT,
          "Authorization" => "Bearer ABC",
        },
      ).to_return(status: 200, body: diff)

      result = tool.invoke
      expect(result[:diff]).to eq(diff)
      expect(result[:error]).to be_nil
    end
  end

  context "with an invalid pull request" do
    let(:repo) { "invalid/repo" }
    let(:pull_id) { 999 }

    it "returns an error message" do
      stub_request(:get, "https://api.github.com/repos/#{repo}/pulls/#{pull_id}").with(
        headers: {
          "Accept" => "application/json",
          "User-Agent" => DiscourseAi::AiBot::USER_AGENT,
        },
      ).to_return(status: 404)

      result = tool.invoke
      expect(result[:diff]).to be_nil
      expect(result[:error]).to include("Failed to retrieve the PR information")
    end
  end
end
