# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminUpcomingChanges < PageObjects::Pages::Base
      def visit
        page.visit("/admin/config/upcoming-changes")
      end

      def change_item(setting_name)
        PageObjects::Components::AdminUpcomingChangeItem.new(setting_name)
      end

      def has_change?(setting_name, description: nil)
        description ||= SiteSettings::LabelFormatter.description(setting_name)
        change_item(setting_name).exists?
        change_item(setting_name).has_text?(description)
        change_item(setting_name).has_text?(
          SiteSettings::LabelFormatter.humanized_name(setting_name),
        )
      end

      def has_no_change?(setting_name)
        change_item(setting_name).does_not_exist?
      end

      def filter_controls
        PageObjects::Components::AdminFilterControls.new(
          ".upcoming-changes",
          has_multiple_dropdowns: true,
        )
      end

      def has_enabled_for_success_toast?(enabled_for, translation_args: {})
        enabled_for_text =
          if enabled_for == "specific_groups_with_group_names"
            I18n.t(
              "admin_js.admin.upcoming_changes.enabled_for_options.#{enabled_for}",
              translation_args,
            ).downcase
          else
            I18n.t("admin_js.admin.upcoming_changes.enabled_for_options.#{enabled_for}").downcase
          end

        page.has_content?(
          I18n.t(
            "admin_js.admin.upcoming_changes.change_enabled_for_success",
            enabledFor: enabled_for_text,
          ),
        )
      end

      def has_disabled_success_toast?
        page.has_content?(I18n.t("admin_js.admin.upcoming_changes.change_disabled"))
      end
    end
  end
end
