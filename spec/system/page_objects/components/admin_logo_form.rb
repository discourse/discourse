# frozen_string_literal: true

module PageObjects
  module Components
    class AdminLogoForm < PageObjects::Components::Base
      def image_uploader(image_type)
        PageObjects::Components::UppyImageUploader.new(
          find(".form-kit__container[data-name='#{image_type}']"),
        )
      end

      def upload_image(image_type, image_file)
        image_uploader(image_type).select_image_with_keyboard(image_file.path)
      end

      def remove_image(image_type)
        image_uploader(image_type).remove_image
      end

      def has_no_form_field?(field)
        page.has_no_css?("#control-#{field}")
      end

      def has_form_field?(field)
        page.has_css?("#control-#{field}")
      end

      def toggle_dark_mode(field)
        PageObjects::Components::DToggleSwitch.new(
          ".form-kit__field-toggle[data-name='#{field}'] .d-toggle-switch button",
        ).toggle
      end

      def expand_mobile_section
        find(".admin-logo-form__mobile-section .collapsable").click
      end

      def expand_email_section
        find(".admin-logo-form__email-section .collapsable").click
      end

      def expand_social_media_section
        find(".admin-logo-form__social-media-section .collapsable").click
      end

      def submit
        form.submit
      end

      def has_saved_successfully?
        PageObjects::Components::Toasts.new.has_success?(
          I18n.t("admin_js.admin.config.logo.form.saved"),
        )
      end

      def form
        @form ||= PageObjects::Components::FormKit.new(".admin-logo-form")
      end
    end
  end
end
