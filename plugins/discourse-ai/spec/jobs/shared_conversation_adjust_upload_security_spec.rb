# frozen_string_literal: true

RSpec.describe Jobs::SharedConversationAdjustUploadSecurity do
  subject(:run_job) { described_class.new.execute(params) }

  let(:params) { {} }

  fab!(:claude_2) { Fabricate(:llm_model, name: "claude-2") }

  fab!(:agent) { Fabricate(:ai_agent, default_llm: claude_2).tap(&:ensure_user!) }
  fab!(:bot_user) { agent.user }

  fab!(:user)
  fab!(:topic) { Fabricate(:private_message_topic, user: user, recipient: bot_user) }
  fab!(:post_1) { Fabricate(:post, topic: topic, user: bot_user) }
  fab!(:post_2) { Fabricate(:post, topic: topic, user: user) }
  fab!(:conversation) { SharedAiConversation.share_conversation(user, topic) }

  before { enable_current_plugin }

  context "when conversation is created" do
    let(:params) { { conversation_id: conversation.id } }

    it "does nothing for a conversation that has been deleted before the job ran" do
      conversation.destroy
      SharedAiConversation.any_instance.expects(:update).never
      run_job
    end

    it "does nothing if there weren't any posts with secure uploads in the topic" do
      original_context = conversation.context
      run_job
      expect(conversation.reload.context).to eq(original_context)
    end

    context "when topic posts were rebaked because they had secure uploads" do
      it "keeps only previously shared artifacts that remain in rebaked content" do
        SiteSetting.ai_artifact_security = "strict"
        context = conversation.context
        context.last["artifact_ids"] = [123, 456]
        conversation.update!(context: context)
        post_2.update!(
          cooked:
            "<div class='ai-artifact' data-ai-artifact-id='456'></div>" \
              "<div class='ai-artifact' data-ai-artifact-id='789'></div>",
        )
        allow_any_instance_of(TopicUploadSecurityManager).to receive(:run).and_return([post_2])

        run_job

        saved_post = conversation.reload.context.last
        expect(saved_post["artifact_ids"]).to eq([456])
        expect(saved_post["cooked"]).to include(AiArtifact.url(456))
        expect(conversation.publishes_artifact?(instance_double(AiArtifact, id: 123))).to eq(false)
        expect(conversation.publishes_artifact?(instance_double(AiArtifact, id: 456))).to eq(true)
        expect(conversation.publishes_artifact?(instance_double(AiArtifact, id: 789))).to eq(false)
      end

      it "updates the conversation cooked post content after rebaking" do
        post_2.update!(raw: "some new rebaked content")
        TopicUploadSecurityManager.any_instance.expects(:run).returns([post_2])
        original_context = conversation.context
        run_job
        expect(conversation.reload.context).not_to eq(original_context)
      end

      it "uses the latest saved artifact list when the share changes during rebaking" do
        SiteSetting.ai_artifact_security = "strict"
        context = conversation.context
        context.last["artifact_ids"] = [456]
        conversation.update!(context: context)
        post_2.update!(cooked: "<div class='ai-artifact' data-ai-artifact-id='456'></div>")
        allow_any_instance_of(TopicUploadSecurityManager).to receive(:run) do
          refreshed_context = conversation.reload.context
          refreshed_context.last.delete("artifact_ids")
          refreshed_context.last["username"] = "updated"
          conversation.update!(context: refreshed_context)
          [post_2]
        end

        run_job

        expect(conversation.reload.context.last).to include(
          "artifact_ids" => [],
          "username" => "updated",
        )
      end

      it "preserves an artifact shared after the post was rebaked" do
        SiteSetting.ai_artifact_security = "strict"
        post_2.update!(cooked: "<div class='ai-artifact' data-ai-artifact-id='123'></div>")
        allow_any_instance_of(TopicUploadSecurityManager).to receive(:run) do
          rebaked_post = Post.find(post_2.id)
          post_2.update!(cooked: "<div class='ai-artifact' data-ai-artifact-id='456'></div>")
          context = conversation.reload.context
          context.last["cooked"] = AiArtifact.iframe_for(456)
          context.last["artifact_ids"] = [456]
          conversation.update!(context: context)
          [rebaked_post]
        end

        run_job

        expect(conversation.reload.context.last["artifact_ids"]).to eq([456])
        expect(conversation.context.last["cooked"]).to include(AiArtifact.url(456))
      end
    end
  end

  context "when conversation has been deleted" do
    let(:params) { { target_id: topic.id, target_type: "Topic" } }

    before { conversation.destroy! }

    it "runs the topic upload security manager but doesn't attempt to update a conversation" do
      SharedAiConversation.any_instance.expects(:update).never
      TopicUploadSecurityManager.any_instance.expects(:run).once
      run_job
    end

    it "runs the topic upload security manager if the topic has been trashed" do
      topic.trash!
      TopicUploadSecurityManager.any_instance.expects(:run).once
      run_job
    end
  end
end
