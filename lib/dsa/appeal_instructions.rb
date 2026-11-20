# frozen_string_literal: true

module Dsa
  module AppealInstructions
    def self.message_options
      return {} unless SiteSetting.dsa_reporting_enabled

      email = SiteSetting.dsa_moderation_appeal_email.presence
      return {} unless email

      { body_suffix_key: "system_messages.moderation_appeal_instructions", email: }
    end
  end
end
