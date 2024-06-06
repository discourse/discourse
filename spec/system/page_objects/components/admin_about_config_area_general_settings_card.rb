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
        card.find(".btn-primary.save-card")
      end

      def has_saved_successfully?
        card.has_css?(".successful-save-alert")
      end

      def card
        find(".admin-config-area-card.general-settings-section")
      end
    end
  end
end
