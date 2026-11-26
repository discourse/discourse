# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesUsers < PageObjects::Pages::Base
      SECTIONS = {
        ignored_users: ".user-ignore",
        muted_users: ".user-mute",
        private_messages: ".private-messages",
      }

      def visit(user)
        page.visit("/u/#{user.username}/preferences/users")
        self
      end

      def muted_users_chooser
        PageObjects::Components::SelectKit.new("#{SECTIONS[:muted_users]} .user-chooser")
      end

      def open_ignore_modal
        find("#{SECTIONS[:ignored_users]} .btn-default").click
        PageObjects::Components::SelectKit.new(".ignore-duration-with-username-modal .user-chooser")
      end

      def notice(section = nil)
        PageObjects::Components::AccessNotice.new(SECTIONS[section])
      end

      def has_section?(section)
        has_css?(SECTIONS[section])
      end

      def has_no_section?(section)
        has_css?(".control-label", text: I18n.t("js.user.users")) && has_no_css?(SECTIONS[section])
      end
    end
  end
end
