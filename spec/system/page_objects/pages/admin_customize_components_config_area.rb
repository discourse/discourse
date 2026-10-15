# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminCustomizeComponentsConfigArea < PageObjects::Pages::Base
      class ComponentRow < PageObjects::Components::Base
        def initialize(selector)
          @selector = selector
          @element = browser_root.locator(selector).filter(visible: true)
        end

        def enabled_toggle
          PageObjects::Components::DToggleSwitch.new(
            "#{@selector} .admin-config-components__toggle",
          )
        end

        def edit_button
          @element.locator(".admin-config-components__edit").filter(visible: true)
        end

        def has_author?(name)
          PlaywrightMatchers.contain_text(
            browser_text_pattern(
              I18n.t(
                "admin_js.admin.config_areas.themes_and_components.components.by_author",
                name: name,
              ),
            ),
            useInnerText: true,
          ).matches?(
            @element.locator(".admin-config-components__author-name").filter(visible: true),
          )
        end

        def has_description?(description)
          PlaywrightMatchers.contain_text(
            browser_text_pattern(description),
            useInnerText: true,
          ).matches?(
            @element.locator(".admin-config-components__description").filter(visible: true),
          )
        end

        def has_one_parent_theme?(name)
          @element
            .locator(".admin-config-components__parent-themes")
            .filter(visible: true)
            .inner_text
            .strip == name
        end

        def has_two_parent_themes?(name1, name2)
          @element
            .locator(".admin-config-components__parent-themes")
            .filter(visible: true)
            .inner_text
            .strip ==
            I18n.t(
              "admin_js.admin.config_areas.themes_and_components.components.parent_themes_two",
              name1:,
              name2:,
            )
        end

        def has_three_parent_themes?(name1, name2, name3)
          @element
            .locator(".admin-config-components__parent-themes")
            .filter(visible: true)
            .inner_text
            .strip ==
            I18n.t(
              "admin_js.admin.config_areas.themes_and_components.components.parent_themes_three",
              name1:,
              name2:,
              name3:,
            )
        end

        def has_three_and_more_parent_themes?(name1, name2, name3, count)
          @element
            .locator(".admin-config-components__parent-themes")
            .filter(visible: true)
            .inner_text
            .strip ==
            I18n.t(
              "admin_js.admin.config_areas.themes_and_components.components.parent_themes_more_than_three",
              name1:,
              name2:,
              name3:,
              count:,
            )
        end

        def pending_update?
          PlaywrightMatchers.have_count(0).does_not_match?(
            @element.locator(".admin-config-components__update-available").filter(visible: true),
          )
        end

        def not_pending_update?
          PlaywrightMatchers.have_count(0).matches?(
            @element
              .tap do |parent|
                parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
              end
              .locator(".admin-config-components__update-available")
              .filter(visible: true),
          )
        end

        def more_actions_menu
          PageObjects::Components::DMenu.new(
            @element.locator(".component-menu-trigger").filter(visible: true),
          )
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
        browser_page
          .goto("/admin/config/customize/components")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def component(id)
        ComponentRow.new(".admin-config-components__component-row[data-component-id=\"#{id}\"]")
      end

      def has_no_component?(id)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(
            ".admin-config-components__component-row[data-component-id=\"#{id}\"]",
          ).filter(visible: true),
        )
      end

      def has_component?(id)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".admin-config-components__component-row[data-component-id=\"#{id}\"]",
          ).filter(visible: true),
        )
      end

      def status_selector
        PageObjects::Components::DNativeSelect.new(
          browser_root.locator(".d-filter-controls__dropdown").filter(visible: true),
        )
      end

      def name_filter_input
        browser_root.locator(".d-filter-controls__input").filter(visible: true)
      end

      def has_no_components?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".admin-config-components__component-row").filter(visible: true),
        )
      end

      def has_exact_components?(*ids)
        ids.all? { |id| has_component?(id) } && has_exactly_n_components?(ids.size)
      end

      def has_exactly_n_components?(count)
        PlaywrightMatchers.have_count(count).matches?(
          browser_root.locator(".admin-config-components__component-row").filter(visible: true),
        )
      end

      def components_shown
        expect(
          browser_root.locator(".admin-config-components__component-row").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)

        browser_root
          .locator(".admin-config-components__component-row")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .map { |node| node.get_attribute("data-component-id").to_i }
      end

      def has_name_filter_input?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".d-filter-controls__input").filter(visible: true),
        )
      end

      def has_status_selector?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".d-filter-controls__dropdown").filter(visible: true),
        )
      end

      def has_no_name_filter_input?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".d-filter-controls__input").filter(visible: true),
        )
      end

      def has_no_status_selector?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".d-filter-controls__dropdown").filter(visible: true),
        )
      end

      def has_no_components_installed_text?
        PlaywrightMatchers.contain_text(
          browser_text_pattern(
            I18n.t("admin_js.admin.config_areas.themes_and_components.components.no_components"),
          ),
          useInnerText: true,
        ).matches?(browser_content)
      end

      def has_no_components_found_text?
        PlaywrightMatchers.contain_text(
          browser_text_pattern(
            I18n.t(
              "admin_js.admin.config_areas.themes_and_components.components.no_components_found",
            ),
          ),
          useInnerText: true,
        ).matches?(browser_content)
      end

      def click_install_button
        PageObjects::Components::AdminCustomizeThemeInstallButton.new.click
      end
    end
  end
end
