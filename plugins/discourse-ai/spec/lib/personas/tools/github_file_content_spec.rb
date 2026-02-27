# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::GithubFileContent do
  fab!(:llm_model)
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }

  let(:tool) do
    described_class.new(
      {
        repo_name: "discourse/discourse-ai",
        file_paths: %w[lib/database/connection.rb lib/ai_bot/tools/github_pull_request_diff.rb],
        branch: "8b382d6098fde879d28bbee68d3cbe0a193e4ffc",
      },
      bot_user: nil,
      llm: llm,
    )
  end

  before { enable_current_plugin }

  describe "#invoke" do
    context "when fetching full files" do
      before do
        stub_request(
          :get,
          "https://api.github.com/repos/discourse/discourse-ai/contents/lib/database/connection.rb?ref=8b382d6098fde879d28bbee68d3cbe0a193e4ffc",
        ).to_return(
          status: 200,
          body: { content: Base64.encode64("content of connection.rb") }.to_json,
        )

        stub_request(
          :get,
          "https://api.github.com/repos/discourse/discourse-ai/contents/lib/ai_bot/tools/github_pull_request_diff.rb?ref=8b382d6098fde879d28bbee68d3cbe0a193e4ffc",
        ).to_return(
          status: 200,
          body: { content: Base64.encode64("content of github_pull_request_diff.rb") }.to_json,
        )
      end

      it "retrieves the content of the specified GitHub files" do
        result = tool.invoke
        expected = {
          file_contents:
            "File Path: lib/database/connection.rb:\ncontent of connection.rb\nFile Path: lib/ai_bot/tools/github_pull_request_diff.rb:\ncontent of github_pull_request_diff.rb",
        }

        expect(result).to eq(expected)
      end
    end

    context "when requesting specific line ranges" do
      let(:range_tool) do
        described_class.new(
          { repo_name: "discourse/discourse-ai", file_paths: ["lib/sample.rb#L2-L3"] },
          bot_user: nil,
          llm: llm,
        )
      end

      before do
        stub_request(
          :get,
          "https://api.github.com/repos/discourse/discourse-ai/contents/lib/sample.rb?ref=main",
        ).to_return(
          status: 200,
          body: { content: Base64.encode64("line1\nline2\nline3\nline4\n") }.to_json,
        )

        stub_request(:get, "https://api.github.com/repos/discourse/discourse-ai").to_return(
          status: 200,
          body: { default_branch: "main" }.to_json,
        )
      end

      it "returns only the requested lines with metadata" do
        result = range_tool.invoke
        expect(result[:file_contents]).to include("File Path: lib/sample.rb (lines 2-3):")
        expect(result[:file_contents]).to include("line2\nline3")
      end
    end

    context "when no branch is provided" do
      let(:range_tool) do
        described_class.new(
          { repo_name: "discourse/discourse-ai", file_paths: ["lib/sample.rb#L2-L3"] },
          bot_user: nil,
          llm: llm,
        )
      end

      before do
        stub_request(:get, "https://api.github.com/repos/discourse/discourse-ai").to_return(
          status: 200,
          body: { default_branch: "testing" }.to_json,
        )

        stub_request(
          :get,
          "https://api.github.com/repos/discourse/discourse-ai/contents/lib/sample.rb?ref=testing",
        ).to_return(
          status: 200,
          body: { content: Base64.encode64("line1\nline2\nline3\nline4\n") }.to_json,
        )
      end

      it "uses the default branch" do
        result = range_tool.invoke
        expect(result[:file_contents]).to include("File Path: lib/sample.rb (lines 2-3):")
      end
    end

    context "when file content contains invalid UTF-8 bytes" do
      let(:invalid_utf8_tool) do
        described_class.new(
          { repo_name: "discourse/discourse-ai", file_paths: ["lib/binary.dat"], branch: "main" },
          bot_user: nil,
          llm: llm,
        )
      end

      before do
        binary_payload = +"line1\nabc\xFF\xFEdef\nline3\n"
        binary_payload.force_encoding(Encoding::ASCII_8BIT)

        stub_request(
          :get,
          "https://api.github.com/repos/discourse/discourse-ai/contents/lib/binary.dat?ref=main",
        ).to_return(status: 200, body: { content: Base64.strict_encode64(binary_payload) }.to_json)
      end

      it "normalizes content before truncating" do
        result = nil

        expect { result = invalid_utf8_tool.invoke }.not_to raise_error
        expect(result[:file_contents]).to include("File Path: lib/binary.dat:")
        expect(result[:file_contents]).to include("abcdef")
        expect(result[:file_contents]).to be_valid_encoding
        expect(result[:file_contents].encoding).to eq(Encoding::UTF_8)
      end
    end

    context "when file content contains unicode characters" do
      let(:unicode_tool) do
        described_class.new(
          { repo_name: "discourse/discourse-ai", file_paths: ["lib/unicode.txt"], branch: "main" },
          bot_user: nil,
          llm: llm,
        )
      end

      before do
        stub_request(
          :get,
          "https://api.github.com/repos/discourse/discourse-ai/contents/lib/unicode.txt?ref=main",
        ).to_return(
          status: 200,
          body: { content: Base64.strict_encode64("bonjour é\nこんにちは\n") }.to_json,
        )
      end

      it "preserves valid UTF-8 content" do
        result = unicode_tool.invoke

        expect(result[:file_contents]).to include("File Path: lib/unicode.txt:")
        expect(result[:file_contents]).to include("bonjour é")
        expect(result[:file_contents]).to include("こんにちは")
      end
    end

    context "when repo_name is invalid" do
      let(:invalid_tool) do
        described_class.new(
          { repo_name: "invalid-repo-name", file_paths: ["lib/sample.rb"] },
          bot_user: nil,
          llm: llm,
        )
      end

      it "returns an error for invalid repo_name format" do
        result = invalid_tool.invoke
        expect(result[:error]).to eq("Invalid repo_name format. Expected 'owner/repo'.")
      end
    end
  end

  describe ".signature" do
    it "returns the tool signature" do
      signature = described_class.signature
      expect(signature[:name]).to eq("github_file_content")
      expect(signature[:description]).to eq("Retrieves the content of specified GitHub files")
      expect(signature[:parameters]).to eq(
        [
          {
            name: "repo_name",
            description: "The name of the GitHub repository (e.g., 'discourse/discourse')",
            type: "string",
            required: true,
          },
          {
            name: "file_paths",
            description:
              "The file paths to retrieve. Append '#Lstart-Lend' (e.g., app/models/user.rb#L10-L25) to limit the returned lines",
            type: "array",
            item_type: "string",
            required: true,
          },
          {
            name: "branch",
            description: "The branch or commit SHA to retrieve the files from (default: 'main')",
            type: "string",
            required: false,
          },
        ],
      )
    end
  end
end
