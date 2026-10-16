# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminColorPaletteConfigArea < PageObjects::Pages::Base
      def visit(palette_id)
        browser_page
          .goto("/admin/config/colors/#{palette_id}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      end

      def form
        PageObjects::Components::FormKit.new(".admin-config.color-palettes .form-kit")
      end

      def palette_id
        browser_root
          .locator(form.component)
          .filter(visible: true)
          .get_attribute("data-palette-id")
          .to_i
      end

      def edit_name_button
        browser_root.locator(".admin-config-color-palettes__edit-name").filter(visible: true)
      end

      def name_field
        form.field("name")
      end

      def name_heading
        browser_root.locator(".admin-config-color-palettes__name").filter(visible: true)
      end

      def name_save_button
        browser_root.locator(".admin-config-color-palettes__save-name").filter(visible: true)
      end

      def delete_button
        browser_root.locator(".delete-palette").filter(visible: true)
      end

      def user_selectable_field
        form.field("user_selectable")
      end

      def default_light_on_theme_field
        form.field("default_light_on_theme")
      end

      def default_dark_on_theme_field
        form.field("default_dark_on_theme")
      end

      def color_palette_editor
        PageObjects::Components::ColorPaletteEditor.new(
          form.field("colors").component.locator(".color-palette-editor").filter(visible: true),
        )
      end

      def duplicate_button
        browser_root.locator(".duplicate-palette").filter(visible: true)
      end

      def copy_to_clipboard
        browser_root.locator(".copy-to-clipboard").filter(visible: true).click

        expect(PageObjects::Components::Toasts.new).to have_success(
          I18n.t("admin_js.admin.config_areas.color_palettes.copied_to_clipboard"),
        )
      end

      def has_unsaved_changes_indicator?
        contain_text(
          browser_text_pattern(
            I18n.t("admin_js.admin.config_areas.color_palettes.unsaved_changes"),
          ),
          useInnerText: true,
        ).matches?(browser_content)
      end

      def has_no_unsaved_changes_indicator?
        contain_text(
          browser_text_pattern(
            I18n.t("admin_js.admin.config_areas.color_palettes.unsaved_changes"),
          ),
          useInnerText: true,
        ).does_not_match?(browser_content)
      end
    end
  end
end
