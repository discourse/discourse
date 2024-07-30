# frozen_string_literal: true
module PageObjects
  module Modals
    class AvatarSelector < PageObjects::Modals::Base
      BODY_SELECTOR = ".avatar-selector"
      MODAL_SELECTOR = ".avatar-selector-modal"
      AVATAR_UPLOAD_BUTTON_SELECTOR = ".avatar-uploader__button"

      def select_avatar_upload_option
        body.choose("avatar", option: "custom")
      end

      def select_system_assigned_option
        body.choose("avatar", option: "system")
      end

      def click_avatar_upload_button
        body.find(AVATAR_UPLOAD_BUTTON_SELECTOR).click
      end

      def has_avatar_upload_button?
        has_css?(AVATAR_UPLOAD_BUTTON_SELECTOR)
      end

      def has_no_avatar_upload_button?
        has_no_css?(AVATAR_UPLOAD_BUTTON_SELECTOR)
      end

      def has_user_avatar_image_uploaded?
        body.has_css?(".avatar[src*='uploads/default']")
      end
    end
  end
end
