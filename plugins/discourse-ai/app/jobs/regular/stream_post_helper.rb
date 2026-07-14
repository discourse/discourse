# frozen_string_literal: true

module Jobs
  class StreamPostHelper < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return unless post = Post.includes(:topic).find_by(id: args[:post_id])
      return unless user = User.find_by(id: args[:user_id])
      return unless args[:text]
      return unless args[:progress_channel]
      return unless args[:client_id]

      topic = post.topic
      reply_to = post.reply_to_post
      guardian = user.guardian

      return unless guardian.can_see?(post)

      helper_mode = args[:prompt]

      if helper_mode == DiscourseAi::AiHelper::Assistant::EXPLAIN
        input = <<~TEXT.strip
          <term>#{escape_prompt_tag_value(args[:text])}</term>
          <context>#{escape_prompt_tag_value(post.raw)}</context>
          <topic>#{escape_prompt_tag_value(topic.title)}</topic>
          #{reply_to && guardian.can_see?(reply_to) ? "<replyTo>#{escape_prompt_tag_value(reply_to.raw)}</replyTo>" : nil}
        TEXT
      else
        input = args[:text]
      end

      begin
        DiscourseAi::AiHelper::Assistant.new.stream_prompt(
          helper_mode,
          input,
          user,
          args[:progress_channel],
          custom_prompt: args[:custom_prompt],
          client_id: args[:client_id],
        )
      rescue LlmCreditAllocation::CreditLimitExceeded => e
        publish_error(args[:progress_channel], user, e)
      end
    end

    private

    def escape_prompt_tag_value(value)
      ERB::Util.html_escape(value.to_s)
    end

    def publish_error(channel, user, exception)
      allocation = exception.allocation

      details = {}
      if allocation
        details[:reset_time_relative] = allocation.relative_reset_time
        details[:reset_time_absolute] = allocation.formatted_reset_time
      end

      payload = {
        error: true,
        error_type: "credit_limit_exceeded",
        message: exception.message,
        details: details,
        done: true,
      }

      MessageBus.publish(channel, payload, user_ids: [user.id], max_backlog_age: 60)
    end
  end
end
