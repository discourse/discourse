# frozen_string_literal: true

module PageObjects
  module Components
    module NavigationMenu
      class HeaderDropdown < Base
        def open
          find(".header-dropdown-toggle.hamburger-dropdown").click
          self
        end

        def close
          open
        end

        def has_sidebar_panel?(panel)
          has_css?(
            ".sidebar-hamburger-dropdown .sidebar-section-wrapper[data-section-name=\"#{panel_id(panel)}\"]",
          )
        end

        def has_no_sidebar_panel?(panel)
          has_no_css?(
            ".sidebar-hamburger-dropdown .sidebar-section-wrapper[data-section-name=\"#{panel_id(panel)}\"]",
          )
        end

        def has_dropdown_visible?
          page.has_css?(".sidebar-hamburger-dropdown")
        end

        def has_no_dropdown_visible?
          page.has_no_css?(".sidebar-hamburger-dropdown")
        end

        def visible?
          page.has_css?(".hamburger-dropdown.header-dropdown-toggle")
        end

        def not_visible?
          page.has_no_css?(".hamburger-dropdown.header-dropdown-toggle")
        end

        def click_customize_community_section_button
          community_section.click_button(
            I18n.t("js.sidebar.sections.community.edit_section.header_dropdown"),
          )

          expect(page).to have_no_css(".sidebar-hamburger-dropdown")

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
