# frozen_string_literal: true

module DiscourseEvents
  module Configuration
    class CalendarOrganizerValidator
      def initialize(opts = {})
      end

      def valid_value?(value)
        return true if value.blank?
        return false unless EmailAddressValidator.valid_value?(value)
        return false if Group.find_by_email(value) || Category.find_by_email(value)

        reply_address = SiteSetting.reply_by_email_address
        return true if reply_address.blank?
        pattern = Regexp.escape(reply_address).gsub("%\\{reply_key\\}", ".*")
        !value.match?(/\A#{pattern}\z/i)
      end

      def error_message
        I18n.t("site_settings.event_calendar_invitations_organizer_invalid")
      end
    end
  end
end
