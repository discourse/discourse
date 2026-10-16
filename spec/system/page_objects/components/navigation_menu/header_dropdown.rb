# frozen_string_literal: true

module PageObjects
  module Components
    module NavigationMenu
      class HeaderDropdown < Base
        def open
          browser_root
            .locator(".header-dropdown-toggle.hamburger-dropdown")
            .filter(visible: true)
            .click
          self
        end

        def close
          open
        end

        def has_sidebar_panel?(panel)
          have_count(0).does_not_match?(
            browser_root.locator(
              ".sidebar-hamburger-dropdown .sidebar-section-wrapper[data-section-name=\"#{panel_id(panel)}\"]",
            ).filter(visible: true),
          )
        end

        def has_no_sidebar_panel?(panel)
          have_count(0).matches?(
            browser_root.locator(
              ".sidebar-hamburger-dropdown .sidebar-section-wrapper[data-section-name=\"#{panel_id(panel)}\"]",
            ).filter(visible: true),
          )
        end

        def has_dropdown_visible?
          have_count(0).does_not_match?(
            browser_root.locator(".sidebar-hamburger-dropdown").filter(visible: true),
          )
        end

        def has_no_dropdown_visible?
          have_count(0).matches?(
            browser_root.locator(".sidebar-hamburger-dropdown").filter(visible: true),
          )
        end

        def visible?
          have_count(0).does_not_match?(
            browser_root.locator(".hamburger-dropdown.header-dropdown-toggle").filter(
              visible: true,
            ),
          )
        end

        def not_visible?
          have_count(0).matches?(
            browser_root.locator(".hamburger-dropdown.header-dropdown-toggle").filter(
              visible: true,
            ),
          )
        end

        def click_customize_community_section_button
          community_section
            .locator(
              "[id=#{I18n.t("js.sidebar.sections.community.edit_section.header_dropdown").to_s.to_json}], [name=#{I18n.t("js.sidebar.sections.community.edit_section.header_dropdown").to_s.to_json}]",
            )
            .or(
              community_section.get_by_role(
                "button",
                name: I18n.t("js.sidebar.sections.community.edit_section.header_dropdown"),
              ),
            )
            .filter(visible: true)
            .click

          expect(
            browser_root.locator(".sidebar-hamburger-dropdown").filter(visible: true),
          ).to have_count(0)

          PageObjects::Modals::SidebarSectionForm.new
        end

        private

        def panel_id(panel)
          if panel == "admin"
            "admin-root"
          elsif panel == "main"
            "community"
          end
        end
      end
    end
  end
end
