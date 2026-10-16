# frozen_string_literal: true

module PageObjects
  module Components
    class AdminFontsForm < PageObjects::Components::Base
      def select_font(section, font)
        browser_root
          .locator(
            "[data-name='#{section}_font'] .admin-fonts-form__button-option.body-font-#{font}",
          )
          .filter(visible: true)
          .click
        have_count(0).does_not_match?(
          browser_root.locator(
            "[data-name='#{section}_font'] .admin-fonts-form__button-option.body-font-#{font}.active",
          ).filter(visible: true),
        )
      end

      def select_default_text_size(size)
        browser_root.locator(".admin-fonts-form__button-option.#{size}").filter(visible: true).click
        have_count(0).does_not_match?(
          browser_root.locator(".admin-fonts-form__button-option.#{size}.active").filter(
            visible: true,
          ),
        )
      end

      def active_font(section)
        browser_root
          .locator("[data-name='#{section}_font'] .admin-fonts-form__button-option.active")
          .filter(visible: true)
          .inner_text
          .strip
      end

      def has_no_font?(section, font)
        have_count(0).matches?(
          browser_root.locator(
            "[data-name='#{section}_font'] .admin-fonts-form__button-option.body-font-#{font}",
          ).filter(visible: true),
        )
      end

      def show_more_fonts(section)
        browser_root
          .locator("[data-name='#{section}_font'] .admin-fonts-form__more")
          .filter(visible: true)
          .click
      end

      def has_form_field?(field)
        have_count(0).does_not_match?(
          browser_root.locator("#control-#{field}").filter(visible: true),
        )
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
