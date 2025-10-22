# frozen_string_literal: true
module DiscourseAi
  module Automation
    module LlmPersonaTriage
      def self.handle(post:, persona_id:, whisper: false, silent_mode: false, automation: nil)
        DiscourseAi::AiBot::Playground.reply_to_post(
          post: post,
          persona_id: persona_id,
          whisper: whisper,
          silent_mode: silent_mode,
          feature_name: "automation - #{automation&.name}",
        )
      rescue => e
        Discourse.warn_exception(
          e,
          message: "Error responding to: #{post&.url} in LlmPersonaTriage.handle",
        )
        raise e if Rails.env.test?
        nil
      end
    end
  end
end
