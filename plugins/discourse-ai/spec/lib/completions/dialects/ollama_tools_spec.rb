# frozen_string_literal: true

require_relative "dialect_context"

RSpec.describe DiscourseAi::Completions::Dialects::OllamaTools do
  before { enable_current_plugin }

  describe "#translated_tools" do
    it "translates a tool from our generic format to the Ollama format" do
      tool = {
        name: "github_file_content",
        description: "Retrieves the content of specified GitHub files",
        parameters: [
          {
            name: "repo_name",
            description: "The name of the GitHub repository (e.g., 'discourse/discourse')",
            type: "string",
            required: true,
          },
          {
            name: "file_paths",
            description: "The paths of the files to retrieve within the repository",
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
      }

      tools = [DiscourseAi::Completions::ToolDefinition.from_hash(tool)]
      ollama_tools = described_class.new(tools)

      translated_tools = ollama_tools.translated_tools

      expect(translated_tools).to eq(
        [
          {
            type: "function",
            function: {
              name: "github_file_content",
              description: "Retrieves the content of specified GitHub files",
              parameters: {
                type: "object",
                properties: {
                  "repo_name" => {
                    description: "The name of the GitHub repository (e.g., 'discourse/discourse')",
                    type: :string,
                  },
                  "file_paths" => {
                    description: "The paths of the files to retrieve within the repository",
                    type: :array,
                    items: {
                      type: :string,
                    },
                  },
                  "branch" => {
                    description:
                      "The branch or commit SHA to retrieve the files from (default: 'main')",
                    type: :string,
                  },
                },
                required: %w[repo_name file_paths],
              },
            },
          },
        ],
      )
    end
  end

  describe "#from_raw_tool_call" do
    it "converts a raw tool call to the Ollama tool format" do
      raw_message = {
        content: '{"repo_name":"discourse/discourse","file_paths":["README.md"],"branch":"main"}',
      }

      ollama_tools = described_class.new([])
      tool_call = ollama_tools.from_raw_tool_call(raw_message)

      expect(tool_call).to eq(
        {
          role: "assistant",
          content: nil,
          tool_calls: [
            {
              type: "function",
              function: {
                repo_name: "discourse/discourse",
                file_paths: ["README.md"],
                branch: "main",
                name: nil,
              },
            },
          ],
        },
      )
    end
  end

  describe "#from_raw_tool" do
    it "converts a raw tool to the Ollama tool format" do
      raw_message = { content: "Hello, world!", name: "github_file_content" }

      ollama_tools = described_class.new([])
      tool = ollama_tools.from_raw_tool(raw_message)

      expect(tool).to eq({ role: "tool", content: "Hello, world!", name: "github_file_content" })
    end
  end
end
