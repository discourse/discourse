# frozen_string_literal: true

module Dsa
  class ModerationNotice
    def initialize(community_rule:)
      @community_rule = community_rule
    end

    def enqueue(user_id:, message_type:, message_options:, delay: 0)
      unless SiteSetting.dsa_reporting_enabled && @community_rule
        return SystemMessage.enqueue(user_id:, message_type:, message_options:, delay:)
      end

      Jobs.enqueue_in(
        delay,
        :send_dsa_moderation_notice,
        user_id:,
        message_type:,
        message_options:,
        community_rule: @community_rule,
      )
    end

    def self.message_options(community_rule:, message_type:, message_options:, locale:)
      return message_options unless SiteSetting.dsa_reporting_enabled

      reason_key =
        if message_type.to_s == "flags_agreed_and_post_deleted_for_responders"
          "system_messages.moderation_reason_for_responders"
        else
          "system_messages.moderation_reason"
        end
      reason =
        I18n.t(
          reason_key,
          ground: community_rule.fetch("ground"),
          explanation: community_rule.fetch("explanation"),
          locale:,
        )

      message_options.merge(flag_reason: "#{message_options.fetch(:flag_reason)}\n\n#{reason}")
    end
  end
end
