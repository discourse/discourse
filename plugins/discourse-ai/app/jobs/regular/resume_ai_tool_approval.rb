# frozen_string_literal: true

module Jobs
  class ResumeAiToolApproval < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return if !SiteSetting.ai_bot_enabled

      reviewable = ReviewableAiToolAction.find_by(id: args[:reviewable_id])
      return if !reviewable || !(reviewable.approved? || reviewable.rejected?)

      continuation = reviewable.payload["continuation"]
      return if continuation.blank?

      if continuation["chat_message_id"]
        return if !defined?(::Chat::Message) || !SiteSetting.chat_enabled

        approval_message = ::Chat::Message.find_by(id: continuation["chat_message_id"])
        message = ::Chat::Message.find_by(id: reviewable.payload["chat_message_id"])
        return if !approval_message || !message

        channel = message.chat_channel
        return if !channel.direct_message_channel? || approval_message.chat_channel_id != channel.id
        return if approval_message.thread_id != message.thread_id

        user = message.user
        return if !user || user.bot? || !user.guardian.can_send_direct_message?(channel)
        return if !user.guardian.can_create_chat_message?
        return if !user.guardian.can_create_channel_message?(channel)
      else
        post = Post.includes(:topic).find_by(id: continuation["post_id"])
        return if !post || post.topic_id != reviewable.topic_id

        authorization_user_id =
          post.custom_fields[
            DiscourseAi::AiBot::POST_AI_AGENT_AUTHORIZATION_USER_ID_FIELD
          ].presence || reviewable.target_post&.user_id
        user = User.find_by(id: authorization_user_id)
        return if !user || user.bot? || !user.guardian.can_see?(post)
      end

      tool_action = reviewable.target
      return if !tool_action

      agent = DiscourseAi::Agents::Agent.find_by(user: user, id: tool_action.ai_agent_id)
      bot_user = User.find_by(id: tool_action.bot_user_id)
      return if !agent || !bot_user

      if message
        return if !agent.allow_chat_direct_messages
        return if !channel.allowed_user_ids.include?(agent.user_id)
      end

      model = LlmModel.find_by(id: reviewable.payload["llm_model_id"])
      bot = DiscourseAi::Agents::Bot.as(bot_user, agent: agent.new, model: model)

      reviewable.with_lock do
        return if reviewable.payload["continuation_started_at"].present?
        reviewable.payload["continuation_started_at"] = Time.current.iso8601
        reviewable.save!
      end

      decision = {
        tool: tool_action.tool_name,
        parameters: tool_action.tool_parameters,
        decision: reviewable.status,
        result: continuation["tool_result"],
      }

      custom_instructions = <<~TEXT.strip
          You are continuing after a human resolved a tool approval request.
          The final message contains the decision and the actual tool result as JSON data.
          If approved, the tool has already executed: use its result and do not execute it again.
          If rejected, the tool was not executed: acknowledge the decision and do not retry it or
          perform an equivalent action through another tool. Continue any remaining permitted work,
          or ask the user how to proceed if the rejected action was necessary.
          Subsequent actions still require their normal approvals.
        TEXT
      additional_messages = [{ type: :user, content: decision.to_json }]
      playground = DiscourseAi::AiBot::Playground.new(bot)

      if message
        playground.reply_to_chat_message(
          message,
          channel,
          reviewable.payload["context_post_ids"],
          custom_instructions: custom_instructions,
          additional_messages: additional_messages,
        )
      else
        playground.reply_to(
          post,
          attributed_user: user,
          authorization_user_id: user.id,
          feature_name: "bot",
          auto_set_title: false,
          custom_instructions: custom_instructions,
          additional_messages: additional_messages,
        )
      end
    end
  end
end
