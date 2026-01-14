# frozen_string_literal: true

RSpec.describe Jobs::SharedConversationAdjustUploadSecurity do
  let(:params) { {} }

  fab!(:claude_2) { Fabricate(:llm_model, name: "claude-2") }

  fab!(:bot_user) do
    enable_current_plugin
    toggle_enabled_bots(bots: [claude_2])
    SiteSetting.ai_bot_enabled = true
    SiteSetting.ai_bot_allowed_groups = "10"
    SiteSetting.ai_bot_public_sharing_allowed_groups = "10"
    claude_2.reload.user
  end

  fab!(:user)
  fab!(:topic) { Fabricate(:private_message_topic, user: user, recipient: bot_user) }
  fab!(:post_1) { Fabricate(:post, topic: topic, user: bot_user) }
  fab!(:post_2) { Fabricate(:post, topic: topic, user: user) }
  fab!(:conversation) { SharedAiConversation.share_conversation(user, topic) }

  def run_job
    described_class.new.execute(params)
  end

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
      it "updates the conversation cooked post content after rebaking" do
        post_2.update!(raw: "some new rebaked content")
        TopicUploadSecurityManager.any_instance.expects(:run).returns([post_2])
        original_context = conversation.context
        run_job
        expect(conversation.reload.context).not_to eq(original_context)
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

    it "doesn't attempt to run the topic upload security manager if the topic has been deleted" do
      TopicUploadSecurityManager.any_instance.expects(:run).never
      topic.trash!
      run_job
    end
  end
end
