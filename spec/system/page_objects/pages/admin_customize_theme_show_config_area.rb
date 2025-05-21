# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminCustomizeThemeShowConfigArea < PageObjects::Pages::Base
      def initialize(theme_id)
        @theme_id = theme_id
        @path = "/admin/config/customize/themes/#{theme_id}"
      end

      def visit
        page.visit(@path)
      end

      def has_theme_name?(name)
        has_selector?("h2", text: name)
      end

      def has_created_by_section?
        has_selector?(".admin-config-theme__created-by")
      end

      def has_no_created_by_section?
        has_no_selector?(".admin-config-theme__created-by")
      end

      def has_description?(description)
        has_selector?(".admin-config-theme__description", text: description)
      end

      def has_no_description?
        has_no_selector?(".admin-config-theme__description")
      end

      def has_colors_card?
        has_selector?(".admin-config-theme__color-palette-card")
      end

      def has_no_colors_card?
        has_no_selector?(".admin-config-theme__color-palette-card")
      end

      def has_components_with_children?
        has_selector?(".admin-config-theme__child-components-sections")
      end

      def has_child_component?(child_component)
        has_selector?(".admin-config-theme__child-component", text: child_component.name)
      end

      def has_uploads_card?
        has_selector?(".admin-config-theme__uploads-card")
      end

      def has_no_uploads_card?
        has_no_selector?(".admin-config-theme__uploads-card")
      end

      def has_settings_card?
        has_selector?(".admin-config-theme__settings-card")
      end

      def has_no_settings_card?
        has_no_selector?(".admin-config-theme__settings-card")
      end

      def has_translations_card?
        has_selector?(".admin-config-theme__translations-card")
      end

      def has_no_translations_card?
        has_no_selector?(".admin-config-theme__translations-card")
      end

      def has_remote_theme_metadata?
        has_selector?(".admin-config-theme__metadata-links")
      end

      def has_no_remote_theme_metadata?
        has_no_selector?(".admin-config-theme__metadata-links")
      end

      def has_version_metadata?
        has_selector?(
          ".admin-config-theme__metadata-title",
          text: I18n.t("admin_js.admin.config_areas.theme.version"),
        )
      end

      def has_local_version?(sha)
        find(".admin-config-theme__last-updated").has_text?("(#{sha})")
      end

      def has_no_version_metadata?
        has_no_selector?(
          ".admin-config-theme__metadata-title",
          text: I18n.t("admin_js.admin.config_areas.theme.version"),
        )
      end

      def has_last_updated_metadata?
        has_selector?(".admin-config-theme__last-updated")
      end

      def has_theme_storage_metadata?
        has_selector?(
          ".admin-config-theme__metadata-title",
          text: I18n.t("admin_js.admin.config_areas.theme.theme_storage"),
        )
      end

      def has_custom_css_html_section?
        has_selector?(
          ".admin-config-theme__metadata-title",
          text: I18n.t("admin_js.admin.config_areas.theme.custom_css_html"),
        )
      end

      def has_extra_files_section?
        has_selector?(
          ".admin-config-theme__metadata-title",
          text: I18n.t("admin_js.admin.config_areas.theme.extra_files"),
        )
      end

      def has_no_extra_files_section?
        has_no_selector?(
          ".admin-config-theme__metadata-title",
          text: I18n.t("admin_js.admin.config_areas.theme.extra_files"),
        )
      end
    end
  end
end
