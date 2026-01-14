# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::GithubSearchFiles do
  fab!(:llm_model)
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model.id) }

  let(:tool) do
    described_class.new(
      {
        repo: "discourse/discourse-ai",
        keywords: %w[search tool],
        branch: nil, # Let it find the default branch
      },
      bot_user: nil,
      llm: llm,
    )
  end

  before { enable_current_plugin }

  describe "#invoke" do
    let(:default_branch) { "main" }

    before do
      # Stub request to get the default branch
      stub_request(:get, "https://api.github.com/repos/discourse/discourse-ai").to_return(
        status: 200,
        body: { default_branch: default_branch }.to_json,
      )

      # Stub request to get the file tree
      stub_request(
        :get,
        "https://api.github.com/repos/discourse/discourse-ai/git/trees/#{default_branch}?recursive=1",
      ).to_return(
        status: 200,
        body: {
          tree: [
            { path: "lib/modules/ai_bot/tools/github_search_code.rb", type: "blob" },
            { path: "lib/modules/ai_bot/tools/github_file_content.rb", type: "blob" },
          ],
        }.to_json,
      )
    end

    it "retrieves files matching the specified keywords" do
      result = tool.invoke
      expected = {
        branch: "main",
        matching_files: %w[
          lib/modules/ai_bot/tools/github_search_code.rb
          lib/modules/ai_bot/tools/github_file_content.rb
        ],
      }

      expect(result).to eq(expected)
    end

    it "handles missing branches gracefully" do
      stub_request(
        :get,
        "https://api.github.com/repos/discourse/discourse-ai/git/trees/non_existing_branch?recursive=1",
      ).to_return(status: 404, body: "", headers: { "Content-Type" => "application/json" })

      tool_with_invalid_branch =
        described_class.new(
          {
            repo: "discourse/discourse-ai",
            keywords: %w[search tool],
            branch: "non_existing_branch",
          },
          bot_user: nil,
          llm: llm,
        )

      result = tool_with_invalid_branch.invoke
      expect(result[:matching_files]).to be_nil
      expect(result[:error]).to eq("Failed to perform file search. Status code: 404")
    end

    it "fetches the default branch if none is specified" do
      result = tool.invoke
      expect(result[:matching_files]).to match_array(
        %w[
          lib/modules/ai_bot/tools/github_search_code.rb
          lib/modules/ai_bot/tools/github_file_content.rb
        ],
      )
      expect(result[:error]).to be_nil
    end

    it "limits results to MAX_FILE_SEARCH_RESULTS and adds a note when limit is reached" do
      max_results = described_class::MAX_FILE_SEARCH_RESULTS
      matching_files = (1..max_results + 1).map { |i| "lib/tools/search_tool_#{i}.rb" }
      stub_request(
        :get,
        "https://api.github.com/repos/discourse/discourse-ai/git/trees/#{default_branch}?recursive=1",
      ).to_return(
        status: 200,
        body: { tree: matching_files.map { |path| { path: path, type: "blob" } } }.to_json,
      )

      result = tool.invoke
      expect(result[:matching_files].length).to eq(max_results)
      expect(result[:note]).to eq(
        "Result limit reached (#{max_results} files). There may be more matching files.",
      )
    end
  end
end
