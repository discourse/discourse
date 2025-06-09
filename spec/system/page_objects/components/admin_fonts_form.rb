# frozen_string_literal: true

module PageObjects
  module Components
    class AdminFontsForm < PageObjects::Components::Base
      def select_font(section, font)
        find(
          "[data-name='#{section}_font'] .admin-fonts-form__button-option.body-font-#{font}",
        ).click
        page.has_css?(
          "[data-name='#{section}_font'] .admin-fonts-form__button-option.body-font-#{font}.active",
        )
      end

      def select_default_text_size(size)
        find(".admin-fonts-form__button-option.#{size}").click
        page.has_css?(".admin-fonts-form__button-option.#{size}.active")
      end

      def active_font(section)
        find("[data-name='#{section}_font'] .admin-fonts-form__button-option.active").text
      end

      def has_no_font?(section, font)
        page.has_no_css?(
          "[data-name='#{section}_font'] .admin-fonts-form__button-option.body-font-#{font}",
        )
      end

      def show_more_fonts(section)
        find("[data-name='#{section}_font'] .admin-fonts-form__more").click
      end

      def has_form_field?(field)
        page.has_css?("#control-#{field}")
      end

      def submit
        form.submit
      end

      def has_saved_successfully?
        PageObjects::Components::Toasts.new.has_success?(
          I18n.t("admin_js.admin.config.fonts.form.saved"),
        )
      end

      def form
        @form ||= PageObjects::Components::FormKit.new(".admin-fonts-form")
      end
    end
  end
end
