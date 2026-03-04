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

    it "searches for code and groups results by file" do
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
      expect(result[:search_results].length).to eq(1)

      file_entry = result[:search_results].first
      expect(file_entry[:file]).to eq("test/hello.rb")
      expect(file_entry[:total_lines]).to eq(3)
      expect(file_entry[:matches]).to contain_exactly(
        { lines: "1-3", content: "def hellö\n  puts 'hellö'\nend" },
      )

      expect(result[:total_results]).to eq(1)
      expect(result[:page]).to be_nil
      expect(result[:next_page]).to be_nil
      expect(result[:error]).to be_nil
    end
  end

  context "with multiple matches in the same file" do
    let(:repo) { "discourse/discourse" }
    let(:query) { "published_page" }

    it "groups matches under a single file entry" do
      file_content =
        "class Ctrl\n  def show\n    published_page\n  end\n\n  def edit\n    published_page\n  end\nend\n"

      stub_request(
        :get,
        "https://api.github.com/search/code?page=1&per_page=30&q=published_page%20repo:discourse/discourse",
      ).to_return(
        status: 200,
        body: {
          total_count: 1,
          items: [
            {
              path: "app/controllers/ctrl.rb",
              sha: "aaa111",
              url:
                "https://api.github.com/repositories/1/contents/app/controllers/ctrl.rb?ref=main",
              repository: {
                full_name: "discourse/discourse",
                default_branch: "main",
              },
              text_matches: [
                { fragment: "  def show\n    published_page\n  end" },
                { fragment: "  def edit\n    published_page\n  end" },
              ],
            },
          ],
        }.to_json,
      )

      stub_request(
        :get,
        "https://api.github.com/repos/discourse/discourse/git/blobs/aaa111",
      ).to_return(status: 200, body: { content: Base64.encode64(file_content) }.to_json)

      result = tool.invoke
      expect(result[:search_results].length).to eq(1)

      file_entry = result[:search_results].first
      expect(file_entry[:file]).to eq("app/controllers/ctrl.rb")
      expect(file_entry[:matches].length).to eq(2)
      expect(file_entry[:matches][0][:lines]).to eq("2-4")
      expect(file_entry[:matches][1][:lines]).to eq("6-8")
    end
  end

  context "with ignore_paths" do
    let(:repo) { "discourse/discourse" }
    let(:query) { "enable_page_publishing" }

    let(:tool) do
      described_class.new(
        { repo: repo, query: query, ignore_paths: %w[config/locales/ spec/] },
        bot_user: bot_user,
        llm: llm,
      )
    end

    it "excludes files matching ignored path prefixes" do
      stub_request(
        :get,
        "https://api.github.com/search/code?page=1&per_page=30&q=enable_page_publishing%20repo:discourse/discourse",
      ).to_return(
        status: 200,
        body: {
          total_count: 3,
          items: [
            {
              path: "config/site_settings.yml",
              sha: "s1",
              url:
                "https://api.github.com/repositories/1/contents/config/site_settings.yml?ref=main",
              repository: {
                full_name: "discourse/discourse",
                default_branch: "main",
              },
              text_matches: [{ fragment: "enable_page_publishing: true" }],
            },
            {
              path: "config/locales/server.lt.yml",
              sha: "s2",
              url:
                "https://api.github.com/repositories/1/contents/config/locales/server.lt.yml?ref=main",
              repository: {
                full_name: "discourse/discourse",
                default_branch: "main",
              },
              text_matches: [{ fragment: "enable_page_publishing: translated" }],
            },
            {
              path: "spec/requests/published_pages_spec.rb",
              sha: "s3",
              url:
                "https://api.github.com/repositories/1/contents/spec/requests/published_pages_spec.rb?ref=main",
              repository: {
                full_name: "discourse/discourse",
                default_branch: "main",
              },
              text_matches: [{ fragment: "enable_page_publishing = true" }],
            },
          ],
        }.to_json,
      )

      stub_request(:get, "https://api.github.com/repos/discourse/discourse/git/blobs/s1").to_return(
        status: 200,
        body: { content: Base64.encode64("enable_page_publishing: true\n") }.to_json,
      )

      result = tool.invoke
      files = result[:search_results].map { |r| r[:file] }
      expect(files).to eq(["config/site_settings.yml"])
      expect(files).not_to include("config/locales/server.lt.yml")
      expect(files).not_to include("spec/requests/published_pages_spec.rb")
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
      file_entry = result[:search_results].first
      expect(file_entry[:file]).to eq("config/constants.rb")
      expect(file_entry[:total_lines]).to be_nil
      expect(file_entry[:matches]).to contain_exactly({ lines: nil, content: "A_CONSTANT = true" })
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
