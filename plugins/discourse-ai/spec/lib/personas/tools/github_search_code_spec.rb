# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::GithubSearchCode do
  let(:bot_user) { Fabricate(:user) }
  fab!(:llm_model)
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  let(:tool) { described_class.new({ repo: repo, query: query }, bot_user: bot_user, llm: llm) }

  before { enable_current_plugin }

  context "with valid search results" do
    let(:repo) { "discourse/discourse" }
    let(:query) { "def hello" }

    it "searches for code in the repository" do
      file_body = "def hellö\n  puts 'hellö'\nend\n".dup.force_encoding(Encoding::ASCII_8BIT)
      stub_request(
        :get,
        "https://api.github.com/search/code?page=1&per_page=30&q=def%20hello%20repo:discourse/discourse",
      ).with(
        headers: {
          "Accept" => "application/vnd.github.v3.text-match+json",
          "User-Agent" => DiscourseAi::AiBot::USER_AGENT,
        },
      ).to_return(
        status: 200,
        body: {
          total_count: 1,
          items: [
            {
              path: "test/hello.rb",
              name: "hello.rb",
              sha: "abc123",
              url:
                "https://api.github.com/repositories/1/contents/test/hello.rb?ref=main-sha-commit",
              repository: {
                full_name: "discourse/discourse",
                default_branch: "main",
              },
              text_matches: [{ fragment: "def hellö\n  puts 'hellö'\nend" }],
            },
          ],
        }.to_json,
      )
      stub_request(:get, "https://api.github.com/repos/discourse/discourse/git/blobs/abc123").with(
        headers: {
          "Accept" => "application/vnd.github.v3+json",
          "User-Agent" => DiscourseAi::AiBot::USER_AGENT,
        },
      ).to_return(status: 200, body: { content: Base64.encode64(file_body) }.to_json)

      result = tool.invoke
      expect(result[:search_results]).to include(
        file: "test/hello.rb",
        lines: "1-3",
        total_file_lines: 3,
        content: "def hellö\n  puts 'hellö'\nend",
      )
      expect(result[:pagination][:current_page]).to eq(1)
      expect(result[:pagination][:total_pages]).to eq(1)
      expect(result[:error]).to be_nil
    end
  end

  context "with partial metadata" do
    let(:repo) { "discourse/discourse" }
    let(:query) { "A_CONSTANT" }

    it "falls back gracefully when file content cannot be retrieved" do
      stub_request(
        :get,
        "https://api.github.com/search/code?page=1&per_page=30&q=A_CONSTANT%20repo:discourse/discourse",
      ).with(
        headers: {
          "Accept" => "application/vnd.github.v3.text-match+json",
          "User-Agent" => DiscourseAi::AiBot::USER_AGENT,
        },
      ).to_return(
        status: 200,
        body: {
          total_count: 1,
          items: [
            {
              path: "config/constants.rb",
              sha: "def456",
              url: "https://api.github.com/repositories/1/contents/config/constants.rb?ref=main",
              repository: {
                full_name: "discourse/discourse",
                default_branch: "main",
              },
              text_matches: [{ fragment: "A_CONSTANT = true" }],
            },
          ],
        }.to_json,
      )

      stub_request(:get, "https://api.github.com/repos/discourse/discourse/git/blobs/def456").with(
        headers: {
          "Accept" => "application/vnd.github.v3+json",
          "User-Agent" => DiscourseAi::AiBot::USER_AGENT,
        },
      ).to_return(status: 404)

      result = tool.invoke
      expect(result[:search_results]).to include(
        file: "config/constants.rb",
        lines: nil,
        total_file_lines: nil,
        content: "A_CONSTANT = true",
      )
    end
  end

  context "with an empty search result" do
    let(:repo) { "discourse/discourse" }
    let(:query) { "nonexistent_method" }

    describe "#description_args" do
      it "returns the repo and query" do
        expect(tool.description_args).to eq(repo: repo, query: query, page: 1)
      end
    end

    it "returns an empty result" do
      SiteSetting.ai_bot_github_access_token = "ABC"
      stub_request(
        :get,
        "https://api.github.com/search/code?page=1&per_page=30&q=nonexistent_method%20repo:discourse/discourse",
      ).with(
        headers: {
          "Accept" => "application/vnd.github.v3.text-match+json",
          "User-Agent" => DiscourseAi::AiBot::USER_AGENT,
          "Authorization" => "Bearer ABC",
        },
      ).to_return(status: 200, body: { total_count: 0, items: [] }.to_json)

      result = tool.invoke
      expect(result[:search_results]).to be_empty
      expect(result[:error]).to be_nil
    end
  end

  context "with an error response" do
    let(:repo) { "discourse/discourse" }
    let(:query) { "def hello" }

    it "returns an error message" do
      stub_request(
        :get,
        "https://api.github.com/search/code?page=1&per_page=30&q=def%20hello%20repo:discourse/discourse",
      ).with(
        headers: {
          "Accept" => "application/vnd.github.v3.text-match+json",
          "User-Agent" => DiscourseAi::AiBot::USER_AGENT,
        },
      ).to_return(status: 403)

      result = tool.invoke
      expect(result[:search_results]).to be_nil
      expect(result[:error]).to include("Failed to perform code search")
    end
  end
end
