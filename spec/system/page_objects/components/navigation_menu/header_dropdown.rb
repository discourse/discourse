# frozen_string_literal: true

module PageObjects
  module Components
    module NavigationMenu
      class HeaderDropdown < Base
        def open
          find(".header-dropdown-toggle.hamburger-dropdown").click
          expect(page).to have_css(".sidebar-hamburger-dropdown")
          self
        end

        def click_customize_community_section_button
          community_section.click_button(
            I18n.t("js.sidebar.sections.community.edit_section.header_dropdown"),
          )

          expect(page).to have_no_css(".sidebar-hamburger-dropdown")

          PageObjects::Modals::SidebarSectionForm.new
        end
      end
    end
  end
end
