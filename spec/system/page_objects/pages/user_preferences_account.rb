# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesAccount < PageObjects::Pages::Base
      def visit(user)
        browser_page
          .goto("/u/#{user.username}/preferences/account")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def click_edit_avatar_button
        browser_root
          .get_by_role("button")
          .and(
            browser_root.locator(
              "[id=#{"edit-avatar".to_s.to_json}], [name=#{"edit-avatar".to_s.to_json}]",
            ).or(browser_root.get_by_role("button", name: "edit-avatar")),
          )
          .filter(visible: true)
          .click
      end

      def open_avatar_selector_modal(user)
        visit(user).click_edit_avatar_button
      end

      def has_no_avatar_editor?
        have_count(0).matches?(browser_root.locator("#edit-avatar").filter(visible: true))
      end

      def has_custom_uploaded_avatar_image?(upload_id)
        result =
          browser_page.wait_for_function(
            <<~JS,
          selector => {
            return Array.from(document.querySelectorAll(selector)).some(avatar => {
              const bounds = avatar.getBoundingClientRect();
              return avatar.checkVisibility() &&
                getComputedStyle(avatar).visibility === "visible" &&
                bounds.width > 0 && bounds.height > 0 &&
                avatar.complete &&
                avatar.naturalWidth === (parseInt(avatar.src.split("/").at(-2), 10) || 0);
            });
          }
        JS
            arg: ".pref-avatar img.avatar[src*='/#{upload_id}_']",
            timeout: Capybara.default_max_wait_time * 1000,
          )
        result.dispose
        true
      end

      def has_system_avatar_image?
        have_count(0).does_not_match?(
          browser_root.locator(".pref-avatar img.avatar[src*='letter_avatar']").filter(
            visible: true,
          ),
        )
      end
    end
  end
end
