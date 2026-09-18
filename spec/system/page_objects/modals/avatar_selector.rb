# frozen_string_literal: true
module PageObjects
  module Modals
    class AvatarSelector < PageObjects::Modals::Base
      BODY_SELECTOR = ".avatar-selector"
      MODAL_SELECTOR = ".avatar-selector-modal"
      AVATAR_UPLOAD_BUTTON_SELECTOR = ".avatar-uploader__button"

      def select_system_assigned_option
        body.choose("avatar", option: "system")
      end

      def has_no_avatar_upload_button?
        has_no_css?(AVATAR_UPLOAD_BUTTON_SELECTOR)
      end

      def has_avatar_options?(*options)
        ordered_options = options.map { |option| ".avatar-choice--#{option}" }.join(" + ")

        body.has_css?(ordered_options)
      end

      def has_user_avatar_image_uploaded?
        body.has_css?(".avatar[src*='uploads/default']")
      end

      def uploaded_avatar_id
        body.find(AVATAR_UPLOAD_BUTTON_SELECTOR)["data-avatar-upload-id"]
      end

      def upload_image(file_path)
        previous_id = uploaded_avatar_id
        attach_file("custom-profile-upload", file_path, make_visible: true)
        expect(body).to have_css(AVATAR_UPLOAD_BUTTON_SELECTOR) do |button|
          upload_id = button["data-avatar-upload-id"]
          upload_id.present? && upload_id != previous_id
        end
        self
      end

      def has_custom_picture_selected?
        body.has_checked_field?("uploaded-avatar")
      end

      def has_upload_warning_below_choice?
        body.has_css?(".avatar-choice--upload .warning") do |warning|
          label = body.find("label[for='uploaded-avatar']").rect
          warning.rect["y"] >= label["y"] + label["height"]
        end
      end
    end
  end
end
