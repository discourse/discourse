# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesProfile < PageObjects::Pages::Base
      SETTINGS = {
        timezone: ".pref-timezone",
        profile_header: "[data-setting-name='user-profile-bg']",
        card_background: "[data-setting-name='user-card-bg']",
        user_fields: "[data-setting-name='user-user-fields']",
      }

      def visit(user)
        page.visit("/u/#{user.username}/preferences/profile")
        self
      end

      def hide_profile
        find(".user-hide-profile .pref-hide-profile").click
      end

      def has_hidden_profile?
        has_css?(".user-hide-profile .pref-hide-profile input[type=checkbox]:checked")
      end

      def expand_profile_details
        find(".user-main .details .controls .btn-default").click
      end

      def fill_bio(with:)
        find(".bio-composer .d-editor-input").fill_in(with:)
      end

      def save
        find(".save-button .btn-primary").click
      end

      def cooked_bio
        find(".user-main .details .primary .bio")
      end

      def notice(setting = nil)
        PageObjects::Components::AccessNotice.new(SETTINGS[setting])
      end

      def has_use_current_timezone_disabled?
        has_css?("#{SETTINGS[:timezone]} .btn[disabled]")
      end

      def has_use_current_timezone_enabled?
        has_css?("#{SETTINGS[:timezone]} .btn:not([disabled])")
      end

      def has_user_field?(name)
        has_css?(".user-field", text: name)
      end

      def has_staff_only_user_field?(name)
        has_css?(
          "#{SETTINGS[:user_fields]}:has(#{PageObjects::Components::AccessNotice::STAFF_ONLY})",
          text: name,
        )
      end
    end
  end
end
