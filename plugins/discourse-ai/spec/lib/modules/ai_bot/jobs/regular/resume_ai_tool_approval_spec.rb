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
      bot_user_id: llm_model.reload.user_id,
      post_id: source_post.id,
    )
  end

  let(:reviewable) do
    ReviewableAiToolAction.needs_review!(
      target: tool_action,
      created_by: llm_model.reload.user,
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
    it "continues once in the approval post with the actual result and original authorization" do
      reviewable.perform(admin, :approve, post_id: approval_post.id)
      category = Category.find_by!(name: "Bug reports")
      original_raw = approval_post.reload.raw
      prompts = nil

      messages =
        MessageBus.track_publish do
          expect {
            DiscourseAi::Completions::Llm.with_prepared_responses(
              ["The category is ready."],
            ) do |_, _, captured_prompts|
              job.execute(reviewable_id: reviewable.id)
              job.execute(reviewable_id: reviewable.id)
              prompts = captured_prompts
            end
          }.not_to change { topic.posts.count }
        end

      expect(prompts.size).to eq(1)
      decision = JSON.parse(prompts.first.messages.last[:content])
      expect(decision).to include(
        "tool" => "create_category",
        "decision" => "approved",
        "result" =>
          include(
            "category_id" => category.id,
            "url" => "#{Discourse.base_url}/c/bug-reports/#{category.id}",
          ),
      )
      reply = topic.posts.order(:post_number).last
      expect(reply.id).to eq(approval_post.id)
      expect(reply.raw).to eq("#{original_raw}\n\nThe category is ready.")
      updates =
        messages.select { |message| message.channel == "discourse-ai/ai-bot/topic/#{topic.id}" }
      expect(updates).to be_present
      expect(updates.map { |message| message.data[:post_id] }.uniq).to eq([approval_post.id])
      expect(updates.filter_map { |message| message.data[:raw] }).to all(start_with(original_raw))
      expect(reply.user_id).to eq(ai_agent.user_id)
      expect(
        reply.custom_fields[DiscourseAi::AiBot::POST_AI_AGENT_AUTHORIZATION_USER_ID_FIELD].to_i,
      ).to eq(requester.id)
      expect(Category.where(name: "Bug reports").count).to eq(1)
    end

    it "continues after rejection without executing the tool" do
      reviewable.perform(admin, :reject, post_id: approval_post.id)
      original_raw = approval_post.reload.raw
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
        "#{original_raw}\n\nI will leave the categories unchanged.",
      )
      expect(topic.posts.order(:post_number).last.id).to eq(approval_post.id)
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
      expect(next_approval_post.id).to eq(approval_post.id)
      expect(next_approval_post.raw).to include(
        "data-ai-tool-approval-reviewable-id='#{reviewable.id}'",
        "data-ai-tool-approval-reviewable-id='#{next_reviewable.id}'",
      )
      expect(Category.exists?(name: "Feature requests")).to eq(false)

      next_reviewable.perform(admin, :approve, post_id: next_approval_post.id)
      DiscourseAi::Completions::Llm.with_prepared_responses(["Both categories are ready."]) do
        job.execute(reviewable_id: next_reviewable.id)
      end

      expect(Category.exists?(name: "Feature requests")).to eq(true)
      reply = topic.posts.order(:post_number).last
      expect(reply.id).to eq(approval_post.id)
      expect(reply.raw).to start_with(next_approval_post.raw)
      expect(reply.raw).to end_with("Both categories are ready.")
      expect(reply.post_custom_prompt.custom_prompt.last.first).to eq("Both categories are ready.")
      expect(
        reply.custom_fields[DiscourseAi::AiBot::POST_AI_AGENT_AUTHORIZATION_USER_ID_FIELD].to_i,
      ).to eq(requester.id)
    end

    it "appends in public topics and preserves the previous custom prompt" do
      topic.update!(archetype: Archetype.default)
      original_raw = approval_post.raw
      previous_prompt = [["I will create the category.", ai_agent.user.username]]
      approval_post.create_post_custom_prompt!(custom_prompt: previous_prompt)
      reviewable.perform(admin, :approve, post_id: approval_post.id)

      expect {
        DiscourseAi::Completions::Llm.with_prepared_responses(["The category is ready."]) do
          job.execute(reviewable_id: reviewable.id)
        end
      }.not_to change { topic.posts.count }

      expect(approval_post.reload.raw).to eq("#{original_raw}\n\nThe category is ready.")
      prompt = approval_post.post_custom_prompt.custom_prompt
      expect(prompt.first).to eq(previous_prompt.first)
      expect(prompt.last.first).to eq("The category is ready.")
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

  describe "#execute in chat" do
    before do
      SiteSetting.chat_enabled = true
      ai_agent.update!(allow_chat_direct_messages: true)
    end

    let(:channel) do
      Fabricate(
        :direct_message_channel,
        users: [requester, admin, ai_agent.user],
        threading_enabled: true,
      )
    end
    let(:message) { Fabricate(:chat_message, chat_channel: channel, user: requester) }
    let(:thread) { Fabricate(:chat_thread, channel: channel, original_message: message) }
    let(:approval_message) do
      message.update!(thread: thread)
      tool_action.update!(post_id: nil)
      reviewable.update!(payload: reviewable.payload.merge("chat_message_id" => message.id))
      Fabricate(
        :chat_message,
        chat_channel: channel,
        thread: thread,
        user: ai_agent.user,
        blocks: DiscourseAi::AiBot::ChatToolApproval.pending_blocks(reviewable.id),
      )
    end

    it "resumes once in the same thread with the executed tool result" do
      reviewable.perform(admin, :approve, chat_message_id: approval_message.id)
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
      expect(JSON.parse(prompts.first.messages.last[:content])).to include(
        "decision" => "approved",
        "result" => include("category_id" => category.id),
      )
      reply = channel.chat_messages.order(:id).last
      expect(reply.message).to eq("The category is ready.")
      expect(reply.thread_id).to eq(thread.id)
      expect(reply.user_id).to eq(ai_agent.user_id)
      expect(Category.where(name: "Bug reports").count).to eq(1)
    end

    it "continues after rejection without executing the tool" do
      reviewable.perform(admin, :reject, chat_message_id: approval_message.id)
      prompts = nil

      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["I will leave the categories unchanged."],
      ) do |_, _, captured_prompts|
        job.execute(reviewable_id: reviewable.id)
        prompts = captured_prompts
      end

      expect(JSON.parse(prompts.first.messages.last[:content])).to include(
        "decision" => "rejected",
        "result" => nil,
      )
      expect(prompts.first.messages.first[:content]).to include("do not retry it")
      expect(channel.chat_messages.order(:id).last.message).to eq(
        "I will leave the categories unchanged.",
      )
      expect(Category.exists?(name: "Bug reports")).to eq(false)
    end

    it "queues chat approvals with the original context and resumes subsequent approvals" do
      requester.update!(admin: true)
      ai_agent.update!(tools: ["CreateCategory"])
      bot =
        DiscourseAi::Agents::Bot.as(
          ai_agent.user,
          agent: ai_agent.class_instance.new,
          model: llm_model,
        )
      tool_calls =
        ["First category", "Second category"].map do |name|
          DiscourseAi::Completions::ToolCall.new(
            name: "create_category",
            id: name.parameterize,
            parameters: {
              name: name,
              reason: "Organize discussions",
            },
          )
        end

      DiscourseAi::Completions::Llm.with_prepared_responses(
        [tool_calls.first, "Awaiting approval."],
      ) do
        DiscourseAi::AiBot::Playground.new(bot).reply_to_chat_message(
          message,
          channel,
          [source_post.id],
        )
      end

      first_reviewable = ReviewableAiToolAction.order(:id).last
      expect(first_reviewable.payload).to include(
        "chat_message_id" => message.id,
        "context_post_ids" => [source_post.id],
      )
      first_reviewable.perform(
        admin,
        :approve,
        chat_message_id: channel.chat_messages.order(:id).last.id,
      )

      DiscourseAi::Completions::Llm.with_prepared_responses(
        [tool_calls.last, "Awaiting another approval."],
      ) { job.execute(reviewable_id: first_reviewable.id) }

      next_reviewable = ReviewableAiToolAction.order(:id).last
      expect(next_reviewable).to be_pending
      expect(next_reviewable.payload["chat_message_id"]).to eq(message.id)
      expect(Category.exists?(name: "Second category")).to eq(false)
      next_reviewable.perform(
        admin,
        :approve,
        chat_message_id: channel.chat_messages.order(:id).last.id,
      )

      DiscourseAi::Completions::Llm.with_prepared_responses(["Both categories are ready."]) do
        job.execute(reviewable_id: next_reviewable.id)
      end

      reply = channel.chat_messages.order(:id).last
      expect(reply.message).to eq("Both categories are ready.")
      expect(reply.thread_id).to eq(message.reload.thread_id)
      expect(Category.where(name: ["First category", "Second category"]).count).to eq(2)
    end

    it "skips continuation when the original requester loses access" do
      reviewable.perform(admin, :reject, chat_message_id: approval_message.id)
      channel.chatable.direct_message_users.where(user_id: requester.id).delete_all

      expect { job.execute(reviewable_id: reviewable.id) }.not_to change { Chat::Message.count }
      expect(reviewable.reload.payload["continuation_started_at"]).to be_nil
    end

    it "skips continuation when the agent is no longer available to the requester" do
      reviewable.perform(admin, :reject, chat_message_id: approval_message.id)
      ai_agent.update!(allowed_group_ids: [Group::AUTO_GROUPS[:admins]])

      expect { job.execute(reviewable_id: reviewable.id) }.not_to change { Chat::Message.count }
      expect(reviewable.reload.payload["continuation_started_at"]).to be_nil
    end

    it "skips continuation when the source message is deleted" do
      reviewable.perform(admin, :reject, chat_message_id: approval_message.id)
      message.trash!

      expect { job.execute(reviewable_id: reviewable.id) }.not_to change { Chat::Message.count }
      expect(reviewable.reload.payload["continuation_started_at"]).to be_nil
    end
  end
end
