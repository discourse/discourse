# frozen_string_literal: true

module PageObjects
  module Components
    class AdminAboutConfigAreaGeneralSettingsCard < PageObjects::Components::Base
      def community_name_input
        card.find(".community-name-input input")
      end

      def community_summary_input
        card.find(".community-summary-input input")
      end

      def community_description_editor
        card.find(".community-description-input .d-editor-input")
      end

      def banner_image_uploader
        PageObjects::Components::UppyImageUploader.new(card.find(".image-uploader"))
      end

      def save_button
        card.find(".btn-primary.admin-config-area-card__btn-save")
      end

      def has_saved_successfully?
        PageObjects::Components::Toasts.new.has_success?(
          I18n.t("admin_js.admin.config_areas.about.toasts.general_settings_saved"),
        )
      end

      def card
        find(".admin-config-area-about__general-settings-section")
      end
    end
  end
end
