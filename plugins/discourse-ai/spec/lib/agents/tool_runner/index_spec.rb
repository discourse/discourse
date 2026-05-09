# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAi::Agents::ToolRunner do
  fab!(:llm_model) { Fabricate(:llm_model, name: "claude-2") }
  let(:llm) { DiscourseAi::Completions::Llm.proxy(llm_model) }
  fab!(:bot_user) { Discourse.system_user }
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:tool) do
    AiTool.create!(
      name: "test_tool",
      tool_name: "test_tool",
      description: "a test tool",
      script: "function invoke(params) { return { result: 'ok' }; }",
      summary: "test",
      created_by: user,
    )
  end

  def create_tool(script: nil, rag_chunk_tokens: nil, rag_chunk_overlap_tokens: nil)
    AiTool.create!(
      name: "test #{SecureRandom.uuid}",
      tool_name: "test_#{SecureRandom.uuid.underscore}",
      description: "test",
      parameters: [{ name: "query", type: "string", description: "perform a search" }],
      script: script || "function invoke(params) { return params; }",
      created_by_id: 1,
      summary: "Test tool summary",
      rag_chunk_tokens: rag_chunk_tokens || 374,
      rag_chunk_overlap_tokens: rag_chunk_overlap_tokens || 10,
    )
  end

  before { enable_current_plugin }

  describe "RAG index operations" do
    context "when defining RAG fragments" do
      fab!(:cloudflare_embedding_def)

      before do
        SiteSetting.authorized_extensions = "txt"
        SiteSetting.ai_embeddings_selected_model = cloudflare_embedding_def.id
        SiteSetting.ai_embeddings_enabled = true
        Jobs.run_immediately!
      end

      def create_upload(content, filename)
        upload = nil
        Tempfile.create(filename) do |file|
          file.write(content)
          file.rewind

          upload = UploadCreator.new(file, filename).create_for(Discourse.system_user.id)
        end
        upload
      end

      def stub_embeddings
        @counter = 0
        stub_request(:post, cloudflare_embedding_def.url).to_return(
          status: 200,
          body: lambda { |req| { result: { data: [([@counter += 2] * 1024)] } }.to_json },
          headers: {
          },
        )
      end

      it "allows search within uploads" do
        stub_embeddings

        upload1 = create_upload(<<~TXT, "test.txt")
          1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30
        TXT

        upload2 = create_upload(<<~TXT, "test.txt")
          30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50
        TXT

        tool = create_tool(rag_chunk_tokens: 10, rag_chunk_overlap_tokens: 4, script: <<~JS)
          function invoke(params) {
            let result1 = index.search("testing a search", { limit: 1 });
            let result2 = index.search("testing another search", { limit: 3, filenames: ["test.txt"] });

            return [result1, result2];
          }
        JS

        RagDocumentFragment.link_target_and_uploads(tool, [upload1.id, upload2.id])

        result = tool.runner({}, llm: nil, bot_user: nil).invoke

        expected = [
          [{ "fragment" => "44 45 46 47 48 49 50", "metadata" => nil }],
          [
            { "fragment" => "44 45 46 47 48 49 50", "metadata" => nil },
            { "fragment" => "36 37 38 39 40 41 42 43 44 45", "metadata" => nil },
            { "fragment" => "30 31 32 33 34 35 36 37", "metadata" => nil },
          ],
        ]

        expect(result).to eq(expected)

        tool.rag_chunk_tokens = 5
        tool.rag_chunk_overlap_tokens = 2
        tool.save!

        RagDocumentFragment.update_target_uploads(tool, [upload1.id, upload2.id])
        result = tool.runner({}, llm: nil, bot_user: nil).invoke

        expect(result.length).to eq(2)
        expect(result[0][0]["fragment"].length).to eq(8)
        expect(result[1].length).to eq(3)
      end
    end

    describe "#rag_get_file" do
      before { SiteSetting.authorized_extensions = "md|txt" }

      it "returns full file content in fragment order" do
        upload = Fabricate(:upload, original_filename: "skill.md")
        UploadReference.create!(upload: upload, target: tool)

        RagDocumentFragment.create!(
          target: tool,
          upload: upload,
          fragment: "Part 2",
          fragment_number: 2,
        )
        RagDocumentFragment.create!(
          target: tool,
          upload: upload,
          fragment: "Part 1",
          fragment_number: 1,
        )
        RagDocumentFragment.create!(
          target: tool,
          upload: upload,
          fragment: "Part 3",
          fragment_number: 3,
        )

        tool.update!(
          script: "function invoke(params) { return { content: index.getFile(params.filename) }; }",
        )

        runner =
          described_class.new(
            parameters: {
              "filename" => "skill.md",
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        result = runner.invoke

        expect(result["content"]).to eq("Part 1\nPart 2\nPart 3")
      end

      it "returns null for non-existent file" do
        tool.update!(
          script: "function invoke(params) { return { content: index.getFile(params.filename) }; }",
        )

        runner =
          described_class.new(
            parameters: {
              "filename" => "nonexistent.md",
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        result = runner.invoke

        expect(result["content"]).to be_nil
      end

      it "picks the latest upload when duplicate filenames exist" do
        old_upload = Fabricate(:upload, original_filename: "skill.md")
        new_upload = Fabricate(:upload, original_filename: "skill.md")
        UploadReference.create!(upload: old_upload, target: tool)
        UploadReference.create!(upload: new_upload, target: tool)

        RagDocumentFragment.create!(
          target: tool,
          upload: old_upload,
          fragment: "old content",
          fragment_number: 1,
        )
        RagDocumentFragment.create!(
          target: tool,
          upload: new_upload,
          fragment: "new content",
          fragment_number: 1,
        )

        tool.update!(
          script: "function invoke(params) { return { content: index.getFile(params.filename) }; }",
        )

        runner =
          described_class.new(
            parameters: {
              "filename" => "skill.md",
            },
            llm: llm,
            bot_user: bot_user,
            tool: tool,
          )
        result = runner.invoke

        expect(result["content"]).to eq("new content")
      end
    end
  end
end
