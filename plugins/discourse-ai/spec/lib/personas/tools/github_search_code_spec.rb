# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::Personas::Tools::GithubSearchCode do
  let(:bot_user) { Fabricate(:user) }
  fab!(:llm_model)
  let(:llm) { DiscourseAi::Completions::Llm.proxy("custom:#{llm_model.id}") }
  let(:tool) { described_class.new({ repo: repo, query: query }, bot_user: bot_user, llm: llm) }

  before { enable_current_plugin }

  context "with valid search results" do
    let(:repo) { "discourse/discourse" }
    let(:query) { "def hello" }

    it "searches for code in the repository" do
      stub_request(
        :get,
        "https://api.github.com/search/code?q=def%20hello+repo:discourse/discourse",
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
              text_matches: [{ fragment: "def hello\n  puts 'hello'\nend" }],
            },
          ],
        }.to_json,
      )

      result = tool.invoke
      expect(result[:search_results]).to include("def hello\n  puts 'hello'\nend")
      expect(result[:search_results]).to include("test/hello.rb")
      expect(result[:error]).to be_nil
    end
  end

  context "with an empty search result" do
    let(:repo) { "discourse/discourse" }
    let(:query) { "nonexistent_method" }

    describe "#description_args" do
      it "returns the repo and query" do
        expect(tool.description_args).to eq(repo: repo, query: query)
      end
    end

    it "returns an empty result" do
      SiteSetting.ai_bot_github_access_token = "ABC"
      stub_request(
        :get,
        "https://api.github.com/search/code?q=nonexistent_method+repo:discourse/discourse",
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
        "https://api.github.com/search/code?q=def%20hello+repo:discourse/discourse",
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
