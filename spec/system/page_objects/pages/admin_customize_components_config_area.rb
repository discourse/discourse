# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminCustomizeComponentsConfigArea < PageObjects::Pages::Base
      class ComponentRow < PageObjects::Components::Base
        def initialize(selector)
          @selector = selector
          @element = find(selector)
        end

        def enabled_toggle
          PageObjects::Components::DToggleSwitch.new(
            "#{@selector} .admin-config-components__toggle",
          )
        end

        def edit_button
          @element.find(".admin-config-components__edit")
        end

        def has_author?(name)
          @element.find(".admin-config-components__author-name").has_text?(
            I18n.t(
              "admin_js.admin.config_areas.themes_and_components.components.by_author",
              name: name,
            ),
          )
        end

        def has_description?(description)
          @element.find(".admin-config-components__description").has_text?(description)
        end

        def has_one_parent_theme?(name)
          @element.find(".admin-config-components__parent-themes").text == name
        end

        def has_two_parent_themes?(name1, name2)
          @element.find(".admin-config-components__parent-themes").text ==
            I18n.t(
              "admin_js.admin.config_areas.themes_and_components.components.parent_themes_two",
              name1:,
              name2:,
            )
        end

        def has_three_parent_themes?(name1, name2, name3)
          @element.find(".admin-config-components__parent-themes").text ==
            I18n.t(
              "admin_js.admin.config_areas.themes_and_components.components.parent_themes_three",
              name1:,
              name2:,
              name3:,
            )
        end

        def has_three_and_more_parent_themes?(name1, name2, name3, count)
          @element.find(".admin-config-components__parent-themes").text ==
            I18n.t(
              "admin_js.admin.config_areas.themes_and_components.components.parent_themes_more_than_three",
              name1:,
              name2:,
              name3:,
              count:,
            )
        end

        def pending_update?
          @element.has_css?(".admin-config-components__update-available")
        end

        def not_pending_update?
          @element.has_no_css?(".admin-config-components__update-available")
        end

        def more_actions_menu
          PageObjects::Components::DMenu.new(@element.find(".component-menu-trigger"))
        end

        def preview_button
          more_actions_menu.option(".admin-config-components__preview")
        end

        def has_check_for_updates_button?
          more_actions_menu.has_option?(".admin-config-components__check-updates")
        end

        def has_no_check_for_updates_button?
          more_actions_menu.has_no_option?(".admin-config-components__check-updates")
        end

        def check_for_updates_button
          more_actions_menu.option(".admin-config-components__check-updates")
        end

        def has_update_button?
          more_actions_menu.has_option?(".admin-config-components__update")
        end

        def has_no_update_button?
          more_actions_menu.has_no_option?(".admin-config-components__update")
        end

        def update_button
          more_actions_menu.option(".admin-config-components__update")
        end

        def export_button
          more_actions_menu.option(".admin-config-components__export")
        end

        def delete_button
          more_actions_menu.option(".admin-config-components__delete")
        end
      end

      def visit
        page.visit("/admin/config/customize/components")
      end

      def component(id)
        ComponentRow.new(".admin-config-components__component-row[data-component-id=\"#{id}\"]")
      end

      def has_no_component?(id)
        has_no_css?(".admin-config-components__component-row[data-component-id=\"#{id}\"]")
      end

      def has_component?(id)
        has_css?(".admin-config-components__component-row[data-component-id=\"#{id}\"]")
      end

      def status_selector
        PageObjects::Components::DSelect.new(find(".admin-config-components__status-filter select"))
      end

      def name_filter_input
        find(".admin-config-components__name-filter input")
      end

      def has_no_components?
        has_no_css?(".admin-config-components__component-row")
      end

      def has_exact_components?(*ids)
        ids.all? { |id| has_component?(id) } && has_exactly_n_components?(ids.size)
      end

      def has_exactly_n_components?(count)
        has_css?(".admin-config-components__component-row", count:)
      end

      def components_shown
        expect(page).to have_css(".admin-config-components__component-row")

        all(".admin-config-components__component-row").map { |node| node["data-component-id"].to_i }
      end

      def has_name_filter_input?
        has_css?(".admin-config-components__name-filter")
      end

      def has_status_selector?
        has_css?(".admin-config-components__status-filter")
      end

      def has_no_name_filter_input?
        has_no_css?(".admin-config-components__name-filter")
      end

      def has_no_status_selector?
        has_no_css?(".admin-config-components__status-filter")
      end

      def has_no_components_installed_text?
        page.has_text?(
          I18n.t("admin_js.admin.config_areas.themes_and_components.components.no_components"),
        )
      end

      def has_no_components_found_text?
        page.has_text?(
          I18n.t(
            "admin_js.admin.config_areas.themes_and_components.components.no_components_found",
          ),
        )
      end
    end
  end
end
