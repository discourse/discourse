# frozen_string_literal: true

module Jobs
  class StreamComposerHelper < ::Jobs::Base
    sidekiq_options retry: false

    def execute(args)
      return unless args[:prompt]
      return unless user = User.find_by(id: args[:user_id])
      return unless args[:text]
      return unless args[:client_id]
      return unless args[:progress_channel]

      helper_mode = args[:prompt]

      begin
        DiscourseAi::AiHelper::Assistant.new.stream_prompt(
          helper_mode,
          args[:text],
          user,
          args[:progress_channel],
          force_default_locale: args[:force_default_locale],
          client_id: args[:client_id],
          custom_prompt: args[:custom_prompt],
        )
      rescue LlmCreditAllocation::CreditLimitExceeded => e
        publish_error(args[:progress_channel], user, e)
      end
    end

    private

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
