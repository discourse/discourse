# frozen_string_literal: true

module PageObjects
  module Components
    module NavigationMenu
      class Sidebar < Base
        def open_on_mobile
          browser_root
            .locator(
              "[id=#{"toggle-hamburger-menu".to_s.to_json}], [name=#{"toggle-hamburger-menu".to_s.to_json}]",
            )
            .or(browser_root.get_by_role("button", name: "toggle-hamburger-menu"))
            .filter(visible: true)
            .click
          wait_for_animation(browser_root.locator("div.menu-panel").filter(visible: true))
        end

        def click_header_toggle
          browser_root.locator(header_toggle_css).filter(visible: true).click
        end

        def header_toggle_css
          ".header-sidebar-toggle"
        end

        def visible?
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator("#d-sidebar").filter(visible: true),
          )
        end

        def not_visible?
          PlaywrightMatchers.have_count(0).matches?(
            browser_root.locator("#d-sidebar").filter(visible: true),
          )
        end

        def has_no_customize_community_section_button?
          PlaywrightMatchers.have_count(0).matches?(
            community_section
              .get_by_role("button")
              .and(
                community_section.locator(
                  "[id=#{'[data-list-item-name="customize"]'.to_s.to_json}], [name=#{'[data-list-item-name="customize"]'.to_s.to_json}]",
                ).or(
                  community_section.get_by_role(
                    "button",
                    name: '[data-list-item-name="customize"]',
                  ),
                ),
              )
              .filter(visible: true),
          )
        end

        def click_topics_button
          browser_root.locator("[data-list-item-name='everything']").filter(visible: true).click
        end

        def click_customize_community_section_button
          community_section
            .locator(
              "[id=#{I18n.t("js.sidebar.sections.community.edit_section.sidebar").to_s.to_json}], [name=#{I18n.t("js.sidebar.sections.community.edit_section.sidebar").to_s.to_json}]",
            )
            .or(
              community_section.get_by_role(
                "button",
                name: I18n.t("js.sidebar.sections.community.edit_section.sidebar"),
              ),
            )
            .filter(visible: true)
            .click

          expect(
            community_section.locator(".sidebar-more-section-content").filter(visible: true),
          ).to PlaywrightMatchers.have_count(0)

          PageObjects::Modals::SidebarSectionForm.new
        end

        def click_community_section_more_button
          community_section
            .get_by_role("button")
            .and(
              community_section.locator(".#{"sidebar-more-section-trigger".to_s.split.join(".")}"),
            )
            .filter(visible: true)
            .click
          expect(
            community_section.locator(".sidebar-more-section-content").filter(visible: true),
          ).not_to PlaywrightMatchers.have_count(0)
          self
        end

        def custom_section_modal_title
          browser_root.locator("#discourse-modal-title").filter(visible: true)
        end

        def has_panel_header?
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(".sidebar-panel-header").filter(visible: true),
          )
        end

        def has_no_panel_header?
          PlaywrightMatchers.have_count(0).matches?(
            browser_root.locator(".sidebar-panel-header").filter(visible: true),
          )
        end

        def toggle_all_sections
          browser_root.locator(".sidebar-toggle-all-sections").filter(visible: true).click
        end

        def toggle_section(name)
          browser_root
            .locator("[data-section-name='admin-#{name.to_s.downcase}']")
            .filter(visible: true)
            .click
        end

        def click_back_to_forum
          browser_root.locator(".sidebar-sections__back-to-forum").filter(visible: true).click
          self
        end

        def click_search_input
          browser_root.locator(".sidebar-search__input").filter(visible: true).click
        end

        def my_messages
          I18n.t("js.sidebar.sections.community.links.my_messages.content")
        end

        def my_messages_link_css
          ".sidebar-section-link[data-link-name='my-messages']"
        end

        def has_my_messages_link?(text = my_messages)
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(text)],
            useInnerText: true,
          ).matches?(browser_root.locator(my_messages_link_css).filter(visible: true))
        end

        def has_no_my_messages_link?(text = my_messages)
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(text)],
            useInnerText: true,
          ).does_not_match?(browser_root.locator(my_messages_link_css).filter(visible: true))
        end

        def has_my_messages_link_with_unread_icon?
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(
              "#{my_messages_link_css} .sidebar-section-link-suffix.icon.unread",
            ).filter(visible: true),
          )
        end

        def has_my_messages_link_without_unread_icon?
          PlaywrightMatchers.have_count(0).matches?(
            browser_root.locator(
              "#{my_messages_link_css} .sidebar-section-link-suffix.icon.unread",
            ).filter(visible: true),
          )
        end

        def has_my_messages_link_with_unread_count?
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(
              "#{my_messages_link_css} .sidebar-section-link-content-badge",
            ).filter(visible: true),
          )
        end

        def has_active_link?(name)
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(".sidebar-section-link[data-link-name='#{name}'].active").filter(
              visible: true,
            ),
          )
        end

        def has_no_active_links?
          PlaywrightMatchers.have_count(0).matches?(
            browser_root.locator(".sidebar-section-link.active").filter(visible: true),
          )
        end

        def has_exact_url_match_link?(name)
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(
              ".sidebar-section-link[data-link-name='#{name}'].exact-url-match",
            ).filter(visible: true),
          )
        end

        def has_no_exact_url_match_link?(name)
          PlaywrightMatchers.have_count(0).matches?(
            browser_root.locator(
              ".sidebar-section-link[data-link-name='#{name}'].exact-url-match",
            ).filter(visible: true),
          )
        end
      end
    end
  end
end
