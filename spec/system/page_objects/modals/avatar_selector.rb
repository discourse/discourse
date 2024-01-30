# frozen_string_literal: true
module PageObjects
  module Modals
    class AvatarSelector < PageObjects::Modals::Base
      BODY_SELECTOR = ".avatar-selector"
      MODAL_SELECTOR = ".avatar-selector-modal"

      def select_avatar_upload_option
        body.choose("avatar", option: "custom")
      end

      def select_system_assigned_option
        body.choose("avatar", option: "system")
      end

      def click_avatar_upload_button
        body.find_button(I18n.t("js.user.change_avatar.upload_title")).click
      end

      def has_user_avatar_image_uploaded?
        body.has_css?(".avatar[src*='uploads/default']")
      end
    end
  end
end
