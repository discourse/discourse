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
      fab!(:artifact) { Fabricate(:ai_artifact, user: user, post: post_2) }

      let(:security_manager) { instance_spy(TopicUploadSecurityManager, run: [post_2]) }

      before do
        context = conversation.context
        context.find { |post| post["id"] == post_2.id }["artifact_ids"] = [artifact.id]
        conversation.update!(context:)
        allow(TopicUploadSecurityManager).to receive(:new).with(topic).and_return(security_manager)
      end

      it "updates rebaked content without changing artifact permissions" do
        expected_context = conversation.context.deep_dup
        post_2.update!(raw: "some new rebaked content")

        run_job

        expected_context.find { |post| post["id"] == post_2.id }["cooked"] = post_2.cooked
        expect(conversation.reload.context).to eq(expected_context)
      end

      it "preserves permissions removed by a share update during rebaking" do
        allow(security_manager).to receive(:run) do
          post_2.update!(raw: "The artifact was removed before sharing again.")
          context = conversation.reload.context
          context
            .find { |post| post["id"] == post_2.id }
            .merge!("cooked" => post_2.cooked, "artifact_ids" => [])
          conversation.update!(context:)
          [post_2]
        end

        run_job

        shared_post = conversation.reload.context.find { |post| post["id"] == post_2.id }
        expect(shared_post["artifact_ids"]).to eq([])
      end

      it "keeps the conversation deleted when it is unshared during rebaking" do
        allow(security_manager).to receive(:run) do
          conversation.destroy!
          [post_2]
        end

        run_job

        expect(SharedAiConversation.exists?(conversation.id)).to eq(false)
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
