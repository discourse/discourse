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

      DiscourseAi::AiHelper::Assistant.new.stream_prompt(
        helper_mode,
        args[:text],
        user,
        args[:progress_channel],
        force_default_locale: args[:force_default_locale],
        client_id: args[:client_id],
        custom_prompt: args[:custom_prompt],
      )
    end
  end
end
