# frozen_string_literal: true

module DiscourseNarrativeBot
  module PostGuardianExtension
    extend ActiveSupport::Concern

    prepended do
      alias_method :existing_can_create_post?, :can_create_post?

      def can_create_post?(parent)
        if SiteSetting.discourse_narrative_bot_enabled &&
             parent.try(:subtype) == "system_message" &&
             parent.try(:user) == ::DiscourseNarrativeBot::Base.new.discobot_user
          return true
        end

        existing_can_create_post?(parent)
      end
    end
  end
end
