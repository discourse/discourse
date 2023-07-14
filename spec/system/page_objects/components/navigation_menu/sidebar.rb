# frozen_string_literal: true

module PageObjects
  module Components
    module NavigationMenu
      class Sidebar < Base
        def open_on_mobile
          click_button("toggle-hamburger-menu")
        end

        def visible?
          page.has_css?("#d-sidebar")
        end

        def not_visible?
          page.has_no_css?("#d-sidebar")
        end

        def has_no_customize_community_section_button?
          community_section.has_no_button?(class: "sidebar-section-link-button")
        end

        def click_customize_community_section_button
          community_section.click_button(
            I18n.t("js.sidebar.sections.community.edit_section.sidebar"),
          )

          expect(community_section).to have_no_css(".sidebar-more-section-links-details")

          PageObjects::Modals::SidebarSectionForm.new
        end

        def click_community_section_more_button
          community_section.click_button(class: "sidebar-more-section-links-details-summary")
          expect(community_section).to have_css(".sidebar-more-section-links-details")
          self
        end

        def custom_section_modal_title
          find("#discourse-modal-title")
        end
      end
    end
  end
end
