# frozen_string_literal: true

RSpec.describe DiscourseAi::Agents::Tools::ReadArtifact do
  fab!(:llm_model)
  fab!(:bot_user, :admin)

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
          context: DiscourseAi::Agents::BotContext.new(post: post),
        )

      result = tool.invoke {}
      expect(result[:status]).to eq("success")

      new_artifact = AiArtifact.last
      expect(new_artifact.html).to eq(artifact.html)
      expect(new_artifact.css).to eq(artifact.css)
      expect(new_artifact.js).to eq(artifact.js)
      expect(new_artifact.metadata["cloned_from"]).to eq(artifact.id)
      expect(tool.custom_raw).to include(%([ai-artifact id="#{new_artifact.id}"]))
    end

    context "when the source artifact is in a shared private conversation" do
      fab!(:reader, :user)
      fab!(:reader_topic) { Fabricate(:private_message_topic, user: reader) }
      fab!(:reader_post) { Fabricate(:post, user: reader, topic: reader_topic) }
      fab!(:source_topic) { Fabricate(:private_message_topic, user: post.user) }
      fab!(:source_post) do
        Fabricate(:post, user: post.user, topic: source_topic)
        Fabricate(:post, user: post.user, topic: source_topic)
      end

      def import_artifact(url, context_post: reader_post)
        described_class.new(
          { url: url },
          bot_user: bot_user,
          llm: llm_model.to_llm,
          context: DiscourseAi::Agents::BotContext.new(post: context_post),
        ).invoke
      end

      before do
        SiteSetting.ai_artifact_security = "strict"
        SiteSetting.ai_bot_public_sharing_allowed_groups = "10"
        Group.user_trust_level_change!(post.user.id, post.user.trust_level)
        ai_user = Fabricate(:ai_agent, default_llm: llm_model).ensure_user!
        toggle_enabled_bots(bots: [llm_model])
        source_topic.topic_allowed_users.where.not(user_id: post.user_id).delete_all
        source_topic.topic_allowed_users.create!(user: ai_user)
        artifact.update!(post: source_post)
        source_post.update_columns(
          cooked: "<div class='ai-artifact' data-ai-artifact-id='#{artifact.id}'></div>",
        )
      end

      it "imports an artifact while its conversation is shared" do
        share = SharedAiConversation.share_conversation(post.user, source_topic)
        expect(share.publicly_visible?).to eq(true)
        expect(reader.guardian.can_see?(source_post)).to eq(false)

        expect { expect(import_artifact(artifact.url)[:status]).to eq("success") }.to change {
          AiArtifact.count
        }.by(1)

        expect(AiArtifact.last.html).to eq(artifact.html)
        expect(AiArtifact.last.post).to eq(reader_post)
      end

      it "rejects moved artifacts and later private versions after unsharing" do
        share = SharedAiConversation.share_conversation(post.user, source_topic)
        expect(share.publicly_visible?).to eq(true)
        destination = Fabricate(:private_message_topic, user: post.user)
        PostMover.new(source_topic, Discourse.system_user, [source_post.id]).to_topic(
          destination.id,
        )
        SharedAiConversation.destroy_conversation(share)
        artifact.reload.update!(html: "<p>Private update 猫</p>")
        version = artifact.create_new_version(html: "<p>Private saved revision 猫</p>")
        expect(artifact.reload.public?).to eq(true)
        expect(reader.guardian.can_see?(source_post.reload)).to eq(false)

        expect do
          [artifact.url, "#{artifact.url}/#{version.version_number}"].each do |url|
            expect(import_artifact(url)).to eq(status: "error", error: "Access denied")
          end
        end.not_to change { AiArtifact.count }

        expect(import_artifact(artifact.url, context_post: source_post)[:status]).to eq("success")
      end

      it "rejects artifacts when conversation sharing permission is revoked" do
        share = SharedAiConversation.share_conversation(post.user, source_topic)
        expect(share.publicly_visible?).to eq(true)
        SiteSetting.ai_bot_public_sharing_allowed_groups = ""
        expect(share.publicly_visible?).to eq(false)
        expect(artifact.reload.public?).to eq(true)

        expect do
          expect(import_artifact(artifact.url)).to eq(status: "error", error: "Access denied")
        end.not_to change { AiArtifact.count }
      end
    end

    it "uses visibility permissions when the reply is attributed to another user" do
      private_topic = Fabricate(:private_message_topic)
      private_post = Fabricate(:post, topic: private_topic, user: private_topic.user)
      private_artifact = Fabricate(:ai_artifact, post: private_post, user: private_topic.user)
      context =
        DiscourseAi::Agents::BotContext.new(
          post: post,
          user: Discourse.system_user,
          guardian: post.user.guardian,
        )
      tool =
        described_class.new(
          { url: "#{Discourse.base_url}/discourse-ai/ai-bot/artifacts/#{private_artifact.id}" },
          bot_user: bot_user,
          llm: llm_model.to_llm,
          context: context,
        )

      expect(tool.invoke {}).to eq(status: "error", error: "Access denied")
    end

    it "checks the supplied guardian even when the post author can see the private source" do
      private_topic = Fabricate(:private_message_topic)
      private_post = Fabricate(:post, topic: private_topic, user: private_topic.user)
      private_artifact = Fabricate(:ai_artifact, post: private_post, user: private_topic.user)
      context =
        DiscourseAi::Agents::BotContext.new(
          post: private_post,
          user: Discourse.system_user,
          guardian: post.user.guardian,
        )
      tool =
        described_class.new(
          { url: private_artifact.url },
          bot_user: bot_user,
          llm: llm_model.to_llm,
          context: context,
        )

      expect {
        expect(tool.invoke {}).to eq(status: "error", error: "Access denied")
      }.not_to change { AiArtifact.count }

      context.guardian = private_post.user.guardian
      expect { expect(tool.invoke.fetch(:status)).to eq("success") }.to change {
        AiArtifact.count
      }.by(1)
    end

    it "handles invalid URLs" do
      tool =
        described_class.new(
          { url: "invalid-url" },
          bot_user: bot_user,
          llm: llm_model.to_llm,
          context: DiscourseAi::Agents::BotContext.new(post: post),
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
          context: DiscourseAi::Agents::BotContext.new(post: post),
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
          context: DiscourseAi::Agents::BotContext.new(post: post),
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
          context: DiscourseAi::Agents::BotContext.new(post: post),
        )

      result = tool.invoke {}
      expect(result[:status]).to eq("success")

      new_artifact = AiArtifact.last
      expect(new_artifact.html.length).to be <= described_class::MAX_HTML_SIZE
    end
  end
end
