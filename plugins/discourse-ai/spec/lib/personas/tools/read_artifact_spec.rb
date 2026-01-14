# frozen_string_literal: true

RSpec.describe DiscourseAi::Personas::Tools::ReadArtifact do
  fab!(:llm_model)
  let(:bot_user) { DiscourseAi::AiBot::EntryPoint.find_user_from_model(llm_model.name) }
  fab!(:post)
  fab!(:post2) { Fabricate(:post, user: post.user) }
  fab!(:artifact) do
    AiArtifact.create!(
      user: post.user,
      post: post,
      name: "Test Artifact",
      html: "<div>Test Content</div>",
      css: ".test { color: blue; }",
      js: "console.log('test');",
    )
  end

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
  end

  describe "#invoke" do
    it "successfully reads a local artifact" do
      tool =
        described_class.new(
          { url: "#{Discourse.base_url}/discourse-ai/ai-bot/artifacts/#{artifact.id}" },
          bot_user: bot_user,
          llm: llm_model.to_llm,
          context: DiscourseAi::Personas::BotContext.new(post: post),
        )

      result = tool.invoke {}
      expect(result[:status]).to eq("success")

      new_artifact = AiArtifact.last
      expect(new_artifact.html).to eq(artifact.html)
      expect(new_artifact.css).to eq(artifact.css)
      expect(new_artifact.js).to eq(artifact.js)
      expect(new_artifact.metadata["cloned_from"]).to eq(artifact.id)
    end

    it "handles invalid URLs" do
      tool =
        described_class.new(
          { url: "invalid-url" },
          bot_user: bot_user,
          llm: llm_model.to_llm,
          context: DiscourseAi::Personas::BotContext.new(post: post),
        )

      result = tool.invoke {}
      expect(result[:status]).to eq("error")
      expect(result[:error]).to eq("Invalid URL")
    end

    it "handles non-existent artifacts" do
      tool =
        described_class.new(
          { url: "#{Discourse.base_url}/discourse-ai/ai-bot/artifacts/99999" },
          bot_user: bot_user,
          llm: llm_model.to_llm,
          context: DiscourseAi::Personas::BotContext.new(post: post),
        )

      result = tool.invoke {}
      expect(result[:status]).to eq("error")
      expect(result[:error]).to eq("Artifact not found")
    end

    it "handles external web pages" do
      stub_request(:get, "https://example.com").to_return(status: 200, body: <<~HTML)
            <html>
              <head>
                <link rel="stylesheet" href="/style.css">
              </head>
              <body>
                <main>
                  <div>External Content</div>
                </main>
                <script>console.log('test');</script>
              </body>
            </html>
          HTML

      stub_request(:get, "https://example.com/style.css").to_return(
        status: 200,
        body: ".external { color: red; }",
      )

      tool =
        described_class.new(
          { url: "https://example.com" },
          bot_user: bot_user,
          llm: llm_model.to_llm,
          context: DiscourseAi::Personas::BotContext.new(post: post),
        )

      result = tool.invoke {}
      expect(result[:status]).to eq("success")

      new_artifact = AiArtifact.last
      expect(new_artifact.html).to include("<div>External Content</div>")
      expect(new_artifact.css).to include(".external { color: red; }")
      expect(new_artifact.js).to include("console.log('test');")
      expect(new_artifact.metadata["imported_from"]).to eq("https://example.com")
    end

    it "respects MAX_HTML_SIZE limit" do
      large_content = "x" * (described_class::MAX_HTML_SIZE + 1000)

      stub_request(:get, "https://example.com").to_return(status: 200, body: <<~HTML)
            <html>
              <body>
                <main>#{large_content}</main>
              </body>
            </html>
          HTML

      tool =
        described_class.new(
          { url: "https://example.com" },
          bot_user: bot_user,
          llm: llm_model.to_llm,
          context: DiscourseAi::Personas::BotContext.new(post: post),
        )

      result = tool.invoke {}
      expect(result[:status]).to eq("success")

      new_artifact = AiArtifact.last
      expect(new_artifact.html.length).to be <= described_class::MAX_HTML_SIZE
    end
  end
end
