# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminObjectsSettingEditor < PageObjects::Pages::Base
      def visit_theme(theme, setting_name)
        browser_page
          .goto("/admin/customize/themes/#{theme.id}/schema/#{setting_name}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def visit_setting(setting_name)
        browser_page
          .goto("/admin/schema/#{setting_name}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def has_setting_field?(field_name, value)
        expect(input_field(field_name).input_value).to eq(value)
      end

      def has_setting_field_description?(field_name, description)
        expect(input_field_description(field_name)).to contain_text(
          browser_text_pattern(description),
          useInnerText: true,
        )
      end

      def has_setting_field_label?(field_name, label)
        expect(input_field_label(field_name)).to contain_text(
          browser_text_pattern(label),
          useInnerText: true,
        )
      end

      def click_link(name, child: false)
        browser_root
          .locator(
            ".schema-setting-editor__navigation .schema-setting-editor__tree-node#{child ? ".--child" : ".--parent"}",
          )
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(name))
          .click

        self
      end

      def click_child_link(name)
        click_link(name, child: true)
      end

      def fill_in_field(field_name, value)
        input_field(field_name).fill(value)
        self
      end

      def type_in_field(field_name, value)
        input_field(field_name).press_sequentially(value)
        self
      end

      def add_object_in_root
        browser_root
          .locator(".schema-setting-editor__tree-add-button.--root")
          .filter(visible: true)
          .click
        self
      end

      def save
        browser_root
          .locator(
            "[id=#{I18n.t("js.save").to_s.to_json}], [name=#{I18n.t("js.save").to_s.to_json}]",
          )
          .or(browser_root.get_by_role("button", name: I18n.t("js.save")))
          .filter(visible: true)
          .click
        self
      end

      def back
        browser_root.locator(".customize-show-schema__back").filter(visible: true).click
        self
      end

      private

      def input_field(field_name)
        browser_root.locator(
          ".schema-field[data-name=\"#{field_name}\"] .schema-field__input input",
        ).filter(visible: true)
      end

      def input_field_label(field_name)
        browser_root.locator(
          ".schema-field[data-name=\"#{field_name}\"] .schema-field__label",
        ).filter(visible: true)
      end

      def input_field_description(field_name)
        browser_root.locator(
          ".schema-field[data-name=\"#{field_name}\"] .schema-field__input-description",
        ).filter(visible: true)
      end
    end
  end
end
