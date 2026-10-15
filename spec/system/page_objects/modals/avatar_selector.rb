# frozen_string_literal: true
module PageObjects
  module Modals
    class AvatarSelector < PageObjects::Modals::Base
      BODY_SELECTOR = ".avatar-selector"
      MODAL_SELECTOR = ".avatar-selector-modal"
      AVATAR_UPLOAD_BUTTON_SELECTOR = ".avatar-uploader__button"

      def select_system_assigned_option
        body.locator("input[name=avatar][value=system]").check
      end

      def has_no_avatar_upload_button?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(AVATAR_UPLOAD_BUTTON_SELECTOR).filter(visible: true),
        )
      end

      def has_avatar_options?(*options)
        ordered_options = options.map { |option| ".avatar-choice--#{option}" }.join(" + ")

        PlaywrightMatchers.have_count(0).does_not_match?(
          body.locator(ordered_options).filter(visible: true),
        )
      end

      def has_user_avatar_image_uploaded?
        PlaywrightMatchers.have_count(0).does_not_match?(
          body.locator(".avatar[src*='uploads/default']").filter(visible: true),
        )
      end

      def uploaded_avatar_id
        body
          .locator(AVATAR_UPLOAD_BUTTON_SELECTOR)
          .filter(visible: true)
          .get_attribute("data-avatar-upload-id")
      end

      def upload_image(file_path)
        previous_id = uploaded_avatar_id
        browser_root.locator(
          "input[type='file']:not(:disabled)[id=#{"custom-profile-upload".to_s.to_json}], input[type='file']:not(:disabled)[name=#{"custom-profile-upload".to_s.to_json}]",
        ).set_input_files(file_path)
        selector =
          "#{AVATAR_UPLOAD_BUTTON_SELECTOR}:not([data-avatar-upload-id=#{previous_id.to_s.to_json}])"
        expect(body.locator(selector).filter(visible: true)).to PlaywrightMatchers.have_attribute(
          "data-avatar-upload-id",
          /\S+/,
        )
        self
      end

      def has_custom_picture_selected?
        PlaywrightMatchers.be_checked.matches?(body.locator("#uploaded-avatar"))
      end

      def has_upload_warning_below_choice?
        body.locator(".avatar-choice--upload .warning").wait_for(state: "visible")
        result =
          browser_page.wait_for_function(<<~JS, timeout: Capybara.default_max_wait_time * 1000)
          () => {
            const warning = document.querySelector(".avatar-selector .avatar-choice--upload .warning");
            const label = document.querySelector(".avatar-selector label[for='uploaded-avatar']");
            if (!warning || !label) { return false; }
            const position = label.getBoundingClientRect();
            return warning.getBoundingClientRect().y >= position.y + position.height;
          }
        JS
        result.dispose
        true
      end
    end
  end
end
