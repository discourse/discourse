# frozen_string_literal: true

module PageObjects
  module Pages
    class Rewind < PageObjects::Pages::Base
      def visit_activity(username)
        page.visit("/u/#{username}/activity")
        self
      end

      def visit_my_activity
        page.visit("/my/activity")
        self
      end

      def has_rewind_tab?
        has_selector?(".user-nav__activity-rewind")
      end

      def has_no_rewind_tab?
        has_no_selector?(".user-nav__activity-rewind")
      end

      def has_rewind_notification_active?
        has_css?("body.rewind-notification-active")
      end

      def has_no_rewind_notification_active?
        has_no_css?("body.rewind-notification-active")
      end

      def has_rewind_header_icon?
        has_css?(".rewind-header-icon")
      end

      def has_no_rewind_header_icon?
        has_no_css?(".rewind-header-icon")
      end

      def click_rewind_header_icon
        find(".rewind-header-icon").click
      end

      def click_header_tooltip_cta
        find(".rewind-header-icon-tooltip-content .rewind-header-icon__button").click
      end

      def click_header_tooltip_preferences_link
        find(".rewind-header-icon-tooltip-content .rewind-header-icon__preferences a").click
      end

      def open_user_menu
        find("#toggle-current-user").click
      end

      def click_profile_tab
        click_link("user-menu-button-profile")
      end

      def has_callout?
        has_css?(".rewind-callout__container")
      end

      def has_no_callout?
        has_no_css?(".rewind-callout__container")
      end

      def click_callout
        find(".rewind-callout__container .rewind-callout").click
      end

      def has_rewind_header?
        has_css?(".rewind .rewind__header")
      end

      def on_rewind_page?(username)
        has_current_path?("/u/#{username}/activity/rewind")
      end

      def has_rewind_profile_link?
        has_css?("#quick-access-profile a[href*='/activity/rewind']")
      end

      def has_no_rewind_profile_link?
        has_no_css?("#quick-access-profile a[href*='/activity/rewind']")
      end

      def visit_rewind(username)
        page.visit("/u/#{username}/activity/rewind")
        self
      end

      def has_share_button?
        has_css?(".rewind__share-btn")
      end

      def has_no_share_button?
        has_no_css?(".rewind__share-btn")
      end

      def click_share_button
        find(".rewind__share-btn").click
        self
      end

      def has_viewing_other_user_message?(username)
        has_css?(".rewind-other-user", text: username)
      end

      def has_cannot_view_rewind_error?
        has_css?(".rewind-error")
      end

      def has_no_cannot_view_rewind_error?
        has_no_css?(".rewind-error")
      end

      def has_rewind_loaded?
        has_css?(".rewind__scroll-wrapper")
      end
    end
  end
end
