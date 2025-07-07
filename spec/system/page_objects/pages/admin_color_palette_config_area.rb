# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminColorPaletteConfigArea < PageObjects::Pages::Base
      def visit(palette_id)
        page.visit("/admin/config/colors/#{palette_id}")
      end

      def form
        PageObjects::Components::FormKit.new(".admin-config.color-palettes .form-kit")
      end

      def palette_id
        find(form.component)["data-palette-id"].to_i
      end

      def edit_name_button
        find(".admin-config-color-palettes__edit-name")
      end

      def name_field
        form.field("name")
      end

      def name_heading
        find(".admin-config-color-palettes__name")
      end

      def name_save_button
        find(".admin-config-color-palettes__save-name")
      end

      def delete_button
        find(".delete-palette")
      end

      def user_selectable_field
        form.field("user_selectable")
      end

      def color_palette_editor
        PageObjects::Components::ColorPaletteEditor.new(
          form.field("colors").component.find(".color-palette-editor"),
        )
      end

      def duplicate_button
        page.find(".duplicate-palette")
      end

      def copy_to_clipboard_button
        page.find(".copy-to-clipboard")
      end

      def has_unsaved_changes_indicator?
        page.has_text?(I18n.t("admin_js.admin.config_areas.color_palettes.unsaved_changes"))
      end

      def has_no_unsaved_changes_indicator?
        page.has_no_text?(I18n.t("admin_js.admin.config_areas.color_palettes.unsaved_changes"))
      end
    end
  end
end
