# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::GithubDiff do
  let(:bot_user) { Fabricate(:user) }
  fab!(:llm_model)
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }

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

  context "with parameter validation" do
    let(:repo) { "owner/repo" }

    it "prioritizes sha when both pull_id and sha provided" do
      tool =
        described_class.new(
          { repo: repo, pull_id: 123, sha: "abc123" },
          bot_user: bot_user,
          llm: llm,
        )

      stub_request(:get, "https://api.github.com/repos/#{repo}/commits/abc123").with(
        headers: {
          "Accept" => "application/json",
        },
      ).to_return(status: 404)

      result = tool.invoke
      expect(result[:error]).to include("commit")
    end

    it "returns error when neither pull_id nor sha provided" do
      tool = described_class.new({ repo: repo }, bot_user: bot_user, llm: llm)
      result = tool.invoke
      expect(result[:error]).to eq("Must provide either pull_id or sha")
    end
  end

  context "with a pull request" do
    let(:repo) { "discourse/discourse-automation" }
    let(:pull_id) { 253 }
    let(:tool) do
      described_class.new({ repo: repo, pull_id: pull_id }, bot_user: bot_user, llm: llm)
    end
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
      expect(result[:type]).to eq("pull_request")
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

    it "returns an error for invalid pull request" do
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

    it "handles PRs from deleted forks gracefully" do
      pr_info_deleted_fork = {
        "title" => "Test PR from deleted fork",
        "state" => "closed",
        "user" => nil,
        "created_at" => "2023-01-01T00:00:00Z",
        "updated_at" => "2023-01-02T00:00:00Z",
        "head" => {
          "repo" => nil,
          "ref" => "feature-branch",
          "sha" => "abc123",
        },
        "base" => {
          "repo" => nil,
          "ref" => "main",
        },
      }

      stub_request(:get, "https://api.github.com/repos/#{repo}/pulls/#{pull_id}").with(
        headers: {
          "Accept" => "application/json",
          "User-Agent" => DiscourseAi::AiBot::USER_AGENT,
        },
      ).to_return(status: 200, body: pr_info_deleted_fork.to_json)

      stub_request(:get, "https://api.github.com/repos/#{repo}/pulls/#{pull_id}").with(
        headers: {
          "Accept" => "application/vnd.github.v3.diff",
          "User-Agent" => DiscourseAi::AiBot::USER_AGENT,
        },
      ).to_return(status: 200, body: diff)

      result = tool.invoke
      expect(result[:type]).to eq("pull_request")
      expect(result[:diff]).to eq(diff)
      expect(result[:pr_info][:title]).to eq("Test PR from deleted fork")
      expect(result[:pr_info][:author]).to be_nil
      expect(result[:pr_info][:target][:repo]).to be_nil
      expect(result[:error]).to be_nil
    end
  end

  context "with a commit" do
    let(:repo) { "owner/repo" }
    let(:sha) { "abc123def456" }
    let(:tool) { described_class.new({ repo: repo, sha: sha }, bot_user: bot_user, llm: llm) }
    let(:diff) { <<~DIFF }
      diff --git a/lib/feature.rb b/lib/feature.rb
      index 1234567..89abcdef 100644
      --- a/lib/feature.rb
      +++ b/lib/feature.rb
      @@ -10,3 +10,5 @@
      +def new_method
      +end
    DIFF

    let(:commit_info) do
      {
        "sha" => sha,
        "commit" => {
          "message" => "Fix bug in feature X\n\nThis fixes an issue with...",
          "author" => {
            "name" => "Test Author",
            "date" => "2023-01-01T00:00:00Z",
          },
        },
        "author" => {
          "login" => "test-user",
        },
        "stats" => {
          "additions" => 10,
          "deletions" => 5,
          "total" => 15,
        },
        "files" => [{ "filename" => "lib/feature.rb" }, { "filename" => "spec/feature_spec.rb" }],
      }
    end

    it "retrieves commit info and diff" do
      stub_request(:get, "https://api.github.com/repos/#{repo}/commits/#{sha}").with(
        headers: {
          "Accept" => "application/json",
          "User-Agent" => DiscourseAi::AiBot::USER_AGENT,
        },
      ).to_return(status: 200, body: commit_info.to_json)

      stub_request(:get, "https://api.github.com/repos/#{repo}/commits/#{sha}").with(
        headers: {
          "Accept" => "application/vnd.github.v3.diff",
          "User-Agent" => DiscourseAi::AiBot::USER_AGENT,
        },
      ).to_return(status: 200, body: diff)

      result = tool.invoke
      expect(result[:type]).to eq("commit")
      expect(result[:diff]).to eq(diff)
      expect(result[:commit_info]).to include(
        sha: sha,
        message: "Fix bug in feature X\n\nThis fixes an issue with...",
        author: "Test Author",
        author_login: "test-user",
        files_changed: 2,
      )
      expect(result[:commit_info][:stats]).to include(additions: 10, deletions: 5, total: 15)
      expect(result[:error]).to be_nil
    end

    it "uses the github access token if present" do
      SiteSetting.ai_bot_github_access_token = "ABC"

      stub_request(:get, "https://api.github.com/repos/#{repo}/commits/#{sha}").with(
        headers: {
          "Accept" => "application/json",
          "User-Agent" => DiscourseAi::AiBot::USER_AGENT,
          "Authorization" => "Bearer ABC",
        },
      ).to_return(status: 200, body: commit_info.to_json)

      stub_request(:get, "https://api.github.com/repos/#{repo}/commits/#{sha}").with(
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

    it "returns an error for invalid commit" do
      stub_request(:get, "https://api.github.com/repos/#{repo}/commits/#{sha}").with(
        headers: {
          "Accept" => "application/json",
          "User-Agent" => DiscourseAi::AiBot::USER_AGENT,
        },
      ).to_return(status: 404)

      result = tool.invoke
      expect(result[:diff]).to be_nil
      expect(result[:error]).to include("Failed to retrieve the commit information")
    end
  end
end
