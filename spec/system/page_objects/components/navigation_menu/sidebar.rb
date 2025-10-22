# frozen_string_literal: true

module PageObjects
  module Components
    module NavigationMenu
      class Sidebar < Base
        def open_on_mobile
          click_button("toggle-hamburger-menu")
          wait_for_animation(find("div.menu-panel"))
        end

        def click_header_toggle
          find(header_toggle_css).click
        end

        def header_toggle_css
          ".header-sidebar-toggle"
        end

        def visible?
          page.has_css?("#d-sidebar")
        end

        def not_visible?
          page.has_no_css?("#d-sidebar")
        end

        def has_no_customize_community_section_button?
          community_section.has_no_button?('[data-list-item-name="customize"]')
        end

        def click_topics_button
          page.find("[data-list-item-name='everything']").click
        end

        def click_customize_community_section_button
          community_section.click_button(
            I18n.t("js.sidebar.sections.community.edit_section.sidebar"),
          )

          expect(community_section).to have_no_css(".sidebar-more-section-content")

          PageObjects::Modals::SidebarSectionForm.new
        end

        def click_community_section_more_button
          community_section.click_button(class: "sidebar-more-section-trigger")
          expect(community_section).to have_css(".sidebar-more-section-content")
          self
        end

        def custom_section_modal_title
          find("#discourse-modal-title")
        end

        def has_panel_header?
          page.has_css?(".sidebar-panel-header")
        end

        def has_no_panel_header?
          page.has_no_css?(".sidebar-panel-header")
        end

        def toggle_all_sections
          find(".sidebar-toggle-all-sections").click
        end

        def toggle_section(name)
          find("[data-section-name='admin-#{name.to_s.downcase}']").click
        end

        def click_back_to_forum
          page.find(".sidebar-sections__back-to-forum").click
          self
        end

        def click_search_input
          page.find(".sidebar-search__input").click
        end

        def my_messages
          I18n.t("js.sidebar.sections.community.links.my_messages.content")
        end

        def my_messages_link_css
          ".sidebar-section-link[data-link-name='#{my_messages.downcase.parameterize}']"
        end

        def has_my_messages_link?(text = my_messages)
          page.has_css?(my_messages_link_css, text:)
        end

        def has_no_my_messages_link?(text = my_messages)
          page.has_no_css?(my_messages_link_css, text:)
        end

        def has_my_messages_link_with_unread_icon?
          page.has_css?("#{my_messages_link_css} .sidebar-section-link-suffix.icon.unread")
        end

        def has_my_messages_link_without_unread_icon?
          page.has_no_css?("#{my_messages_link_css} .sidebar-section-link-suffix.icon.unread")
        end

        def has_my_messages_link_with_unread_count?
          page.has_css?("#{my_messages_link_css} .sidebar-section-link-content-badge")
        end

        def has_active_link?(name)
          page.has_css?(".sidebar-section-link[data-link-name='#{name}'].active")
        end

        def has_no_active_links?
          page.has_no_css?(".sidebar-section-link.active")
        end

        def has_exact_url_match_link?(name)
          page.has_css?(".sidebar-section-link[data-link-name='#{name}'].exact-url-match")
        end

        def has_no_exact_url_match_link?(name)
          page.has_no_css?(".sidebar-section-link[data-link-name='#{name}'].exact-url-match")
        end
      end
    end
  end
end
