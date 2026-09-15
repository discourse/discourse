# frozen_string_literal: true

RSpec.describe Jobs::ResumeAiToolApproval do
  subject(:job) { described_class.new }

  fab!(:admin)
  fab!(:requester) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:llm_model) { Fabricate(:llm_model, name: "gpt-3.5-turbo") }
  fab!(:ai_agent) do
    Fabricate(
      :ai_agent,
      allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
      require_approval: true,
    )
  end
  fab!(:topic) { Fabricate(:private_message_topic, user: requester, recipient: admin) }
  fab!(:source_post) { Fabricate(:post, topic: topic, user: requester) }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    toggle_enabled_bots(bots: [llm_model])
    ai_agent.create_user!
    topic.allowed_users << ai_agent.user
  end

  let(:tool_action) do
    AiToolAction.create!(
      tool_name: "create_category",
      tool_parameters: {
        name: "Bug reports",
        reason: "Collect bug reports",
      },
      ai_agent: ai_agent,
      bot_user_id: ai_agent.user_id,
      post_id: source_post.id,
    )
  end

  let(:reviewable) do
    ReviewableAiToolAction.needs_review!(
      target: tool_action,
      created_by: ai_agent.user,
      reviewable_by_moderator: true,
      payload: {
        agent_name: ai_agent.name,
        llm_model_id: llm_model.id,
      },
    )
  end

  let(:approval_post) do
    Fabricate(
      :post,
      topic: topic,
      user: ai_agent.user,
      raw: "<div data-ai-tool-approval-reviewable-id='#{reviewable.id}'></div>",
      custom_fields: {
        DiscourseAi::AiBot::POST_AI_AGENT_AUTHORIZATION_USER_ID_FIELD => requester.id,
      },
    )
  end

  describe "#execute" do
    it "continues once with the actual result and the original user's authorization" do
      reviewable.perform(admin, :approve, post_id: approval_post.id)
      category = Category.find_by!(name: "Bug reports")
      prompts = nil

      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["The category is ready."],
      ) do |_, _, captured_prompts|
        job.execute(reviewable_id: reviewable.id)
        job.execute(reviewable_id: reviewable.id)
        prompts = captured_prompts
      end

      expect(prompts.size).to eq(1)
      decision = JSON.parse(prompts.first.messages.last[:content])
      expect(decision).to include(
        "tool" => "create_category",
        "decision" => "approved",
        "result" => include("category_id" => category.id),
      )
      reply = topic.posts.order(:post_number).last
      expect(reply.raw).to eq("The category is ready.")
      expect(reply.user_id).to eq(ai_agent.user_id)
      expect(
        reply.custom_fields[DiscourseAi::AiBot::POST_AI_AGENT_AUTHORIZATION_USER_ID_FIELD].to_i,
      ).to eq(requester.id)
      expect(Category.where(name: "Bug reports").count).to eq(1)
    end

    it "continues after rejection without executing the tool" do
      reviewable.perform(admin, :reject, post_id: approval_post.id)
      prompts = nil

      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["I will leave the categories unchanged."],
      ) do |_, _, captured_prompts|
        job.execute(reviewable_id: reviewable.id)
        prompts = captured_prompts
      end

      decision = JSON.parse(prompts.first.messages.last[:content])
      expect(decision).to include("decision" => "rejected", "result" => nil)
      expect(prompts.first.messages.first[:content]).to include("do not retry it")
      expect(topic.posts.order(:post_number).last.raw).to eq(
        "I will leave the categories unchanged.",
      )
      expect(Category.exists?(name: "Bug reports")).to eq(false)
    end

    it "requires another approval for a subsequent action and resumes again" do
      requester.update!(admin: true)
      ai_agent.update!(tools: ["CreateCategory"])
      reviewable.perform(admin, :approve, post_id: approval_post.id)
      next_tool_call =
        DiscourseAi::Completions::ToolCall.new(
          name: "create_category",
          id: "create-next-category",
          parameters: {
            name: "Feature requests",
            reason: "Collect feature requests",
          },
        )

      DiscourseAi::Completions::Llm.with_prepared_responses(
        [next_tool_call, "The next category is awaiting approval."],
      ) { job.execute(reviewable_id: reviewable.id) }

      next_reviewable = ReviewableAiToolAction.order(:id).last
      next_approval_post = topic.posts.order(:post_number).last
      expect(next_reviewable).to be_pending
      expect(next_approval_post.raw).to include(
        "data-ai-tool-approval-reviewable-id='#{next_reviewable.id}'",
      )
      expect(Category.exists?(name: "Feature requests")).to eq(false)

      next_reviewable.perform(admin, :approve, post_id: next_approval_post.id)
      DiscourseAi::Completions::Llm.with_prepared_responses(["Both categories are ready."]) do
        job.execute(reviewable_id: next_reviewable.id)
      end

      expect(Category.exists?(name: "Feature requests")).to eq(true)
      reply = topic.posts.order(:post_number).last
      expect(reply.raw).to eq("Both categories are ready.")
      expect(
        reply.custom_fields[DiscourseAi::AiBot::POST_AI_AGENT_AUTHORIZATION_USER_ID_FIELD].to_i,
      ).to eq(requester.id)
    end

    it "skips pending approvals" do
      approval_post

      expect { job.execute(reviewable_id: reviewable.id) }.not_to change { topic.posts.count }
      expect(reviewable.reload.payload["continuation_started_at"]).to be_nil
    end

    it "skips continuation when the requester lost access to the conversation" do
      reviewable.perform(admin, :reject, post_id: approval_post.id)
      topic.topic_allowed_users.where(user_id: requester.id).delete_all

      expect { job.execute(reviewable_id: reviewable.id) }.not_to change { topic.posts.count }
      expect(reviewable.reload.payload["continuation_started_at"]).to be_nil
    end

    it "skips continuation when the agent is no longer available to the requester" do
      reviewable.perform(admin, :reject, post_id: approval_post.id)
      ai_agent.update!(allowed_group_ids: [Group::AUTO_GROUPS[:admins]])

      expect { job.execute(reviewable_id: reviewable.id) }.not_to change { topic.posts.count }
      expect(reviewable.reload.payload["continuation_started_at"]).to be_nil
    end
  end
end
