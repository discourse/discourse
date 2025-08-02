# frozen_string_literal: true

module PageObjects
  module Components
    class AdminAboutConfigAreaGeneralSettingsCard < PageObjects::Components::Base
      def community_name_input
        form.field("name")
      end

      def community_summary_input
        form.field("summary")
      end

      def community_description_editor
        form.field("extendedDescription")
      end

      def community_title_input
        form.field("communityTitle")
      end

      def banner_image_uploader
        PageObjects::Components::UppyImageUploader.new(card.find(".image-uploader"))
      end

      def submit
        form.submit
      end

      def has_saved_successfully?
        PageObjects::Components::Toasts.new.has_success?(
          I18n.t("admin_js.admin.config_areas.about.toasts.general_settings_saved"),
        )
      end

      def card
        find(".admin-config-area-about__general-settings-section")
      end

      def form
        PageObjects::Components::FormKit.new(
          ".admin-config-area-about__general-settings-section .form-kit",
        )
      end
    end
  end
end
