# frozen_string_literal: true

module PageObjects
  module Components
    module NavigationMenu
      class Base < PageObjects::Components::Base
        SIDEBAR_SECTION_LINK_SELECTOR = "sidebar-section-link"

        def visible?
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator("#d-sidebar.sidebar-container").filter(visible: true),
          )
        end

        def hidden?
          PlaywrightMatchers.have_count(0).matches?(
            browser_root.locator("#d-sidebar.sidebar-container").filter(visible: true),
          )
        end

        def community_section
          find_section("community")
        end

        def find_section(name)
          browser_root.locator(sidebar_section_selector(name)).filter(visible: true)
        end

        def click_section_header(name)
          browser_root
            .locator("#{sidebar_section_selector(name)} .sidebar-section-header")
            .filter(visible: true)
            .click
        end

        def click_section_link(name)
          browser_root
            .locator(".#{SIDEBAR_SECTION_LINK_SELECTOR}")
            .filter(visible: true)
            .filter(hasText: browser_text_pattern(name))
            .click
        end

        def click_link_in_section(section_name, link_name)
          find_section(section_name.parameterize)
            .locator(
              ".#{SIDEBAR_SECTION_LINK_SELECTOR}[data-link-name=\"#{link_name.parameterize}\"]",
            )
            .filter(visible: true)
            .click
        end

        def has_community_section_link?(text, href: nil)
          selector = ".#{SIDEBAR_SECTION_LINK_SELECTOR}"
          selector += "[href='#{href}']" if href.present?

          PlaywrightMatchers.contain_text(
            [browser_text_pattern(text)],
            useInnerText: true,
          ).matches?(community_section.locator(selector).filter(visible: true))
        end

        def has_one_active_section_link?
          PlaywrightMatchers.have_count(1).matches?(
            browser_root.locator(".#{SIDEBAR_SECTION_LINK_SELECTOR}--active").filter(visible: true),
          )
        end

        def has_section_link?(name, href: nil, active: false, target: nil, count: 1)
          section_link_present?(
            name,
            href: href,
            active: active,
            target: target,
            present: true,
            count: count,
          )
        end

        def has_no_section_link?(name, href: nil, active: false)
          section_link_present?(name, href: href, active: active, present: false)
        end

        def sidebar_section_selector(name)
          name = name.parameterize if name.include?(" ") || name.match?(/[A-Z]/)
          ".sidebar-sections [data-section-name='#{name}']"
        end

        def has_section?(name)
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(sidebar_section_selector(name)).filter(visible: true),
          )
        end

        def has_no_section?(name)
          PlaywrightMatchers.have_count(0).matches?(
            browser_root.locator(sidebar_section_selector(name)).filter(visible: true),
          )
        end

        def has_section_expanded?(name)
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(
              "#{sidebar_section_selector(name)}.sidebar-section--expanded",
            ).filter(visible: true),
          )
        end

        def has_section_collapsed?(name)
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(
              "#{sidebar_section_selector(name)}.sidebar-section--collapsed",
            ).filter(visible: true),
          )
        end

        def switch_to_chat
          browser_root
            .locator(".sidebar__panel-switch-button[data-key='chat']")
            .filter(visible: true)
            .click
          PlaywrightMatchers.have_count(0).matches?(
            browser_root.locator(".sidebar__panel-switch-button[data-key='chat']").filter(
              visible: true,
            ),
          )
        end

        def switch_to_main
          browser_root
            .locator(".sidebar__panel-switch-button[data-key='main']")
            .filter(visible: true)
            .click
        end

        def has_switch_button?(key = nil)
          if key
            PlaywrightMatchers.have_count(0).does_not_match?(
              browser_root.locator(
                ".sidebar__panel-switch-button[data-key='#{key.parameterize}']",
              ).filter(visible: true),
            )
          else
            PlaywrightMatchers.have_count(0).does_not_match?(
              browser_root.locator(".sidebar__panel-switch-button").filter(visible: true),
            )
          end
        end

        def has_no_switch_button?(key = nil)
          if key
            PlaywrightMatchers.have_count(0).matches?(
              browser_root.locator(
                ".sidebar__panel-switch-button[data-key='#{key.parameterize}']",
              ).filter(visible: true),
            )
          else
            PlaywrightMatchers.have_count(0).matches?(
              browser_root.locator(".sidebar__panel-switch-button").filter(visible: true),
            )
          end
        end

        def has_categories_section?
          has_section?("Categories")
        end

        def has_tags_section?
          has_section?("Tags")
        end

        def has_no_tags_section?
          has_no_section?("Tags")
        end

        def has_all_tags_section_link?
          has_section_link?(I18n.t("js.sidebar.all_tags"))
        end

        def has_tag_section_links?(tags)
          tag_names = tags.map(&:name)

          tag_section_links =
            browser_root
              .locator(
                ".sidebar-section[data-section-name='tags'] .sidebar-section-link-wrapper[data-tag-name]",
              )
              .filter(visible: true)
              .tap do |elements|
                expect(elements).to PlaywrightMatchers.have_count(tag_names.length)
              end
              .all

          expect(tag_section_links.map { |element| element.inner_text.strip }).to eq(tag_names)
        end

        def find_section_link(name)
          browser_root.locator(
            ".#{SIDEBAR_SECTION_LINK_SELECTOR}[data-link-name='#{name}']",
          ).filter(visible: true)
        end

        def primary_section_links(slug)
          browser_root
            .locator("[data-section-name='#{slug}'] .sidebar-section-link-wrapper")
            .filter(visible: true)
            .tap { |elements| elements.first.wait_for(state: "visible") }
            .all
            .map { |element| element.inner_text.strip }
        end

        def primary_section_icons(slug)
          browser_root
            .locator("[data-section-name='#{slug}'] .sidebar-section-link-wrapper use")
            .filter(visible: true)
            .tap { |elements| elements.first.wait_for(state: "visible") }
            .all
            .map do |icon|
              icon.evaluate(
                "(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }",
                arg: "href",
              ).delete_prefix("#")
            end
        end

        def has_category_section_link?(category)
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root
              .get_by_role("link")
              .and(
                browser_root.locator(
                  "[id=#{category.name.to_s.to_json}], [name=#{category.name.to_s.to_json}]",
                ).or(browser_root.get_by_role("link", name: category.name)),
              )
              .and(browser_root.locator(".#{"sidebar-section-link".to_s.split.join(".")}"))
              .filter(visible: true),
          )
        end

        def click_add_section_button
          browser_root
            .locator(
              "[id=#{add_section_button_text.to_s.to_json}], [name=#{add_section_button_text.to_s.to_json}]",
            )
            .or(browser_root.get_by_role("button", name: add_section_button_text))
            .filter(visible: true)
            .click
        end

        def click_add_link_button
          browser_root
            .locator(
              "[id=#{add_link_button_text.to_s.to_json}], [name=#{add_link_button_text.to_s.to_json}]",
            )
            .or(browser_root.get_by_role("button", name: add_link_button_text))
            .filter(visible: true)
            .click
        end

        def has_no_add_section_button?
          PlaywrightMatchers.have_count(0).matches?(
            browser_root.locator(add_section_button_css).filter(visible: true),
          )
        end

        def has_add_section_button?
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(add_section_button_css).filter(visible: true),
          )
        end

        def click_edit_categories_button
          within_browser(
            browser_root.locator(".sidebar-section[data-section-name='categories']").filter(
              visible: true,
            ),
          ) do
            browser_root
              .get_by_role("button")
              .and(browser_root.locator(".#{"sidebar-section-header-button".to_s.split.join(".")}"))
              .click
          end

          expect(
            browser_root.locator(".d-modal:not(.is-animating)").filter(visible: true),
          ).not_to PlaywrightMatchers.have_count(0)

          PageObjects::Modals::SidebarEditCategories.new
        end

        def click_edit_tags_button
          within_browser(
            browser_root.locator(".sidebar-section[data-section-name='tags']").filter(
              visible: true,
            ),
          ) do
            browser_root
              .get_by_role("button")
              .and(browser_root.locator(".#{"sidebar-section-header-button".to_s.split.join(".")}"))
              .click
          end

          expect(
            browser_root.locator(".d-modal:not(.is-animating)").filter(visible: true),
          ).not_to PlaywrightMatchers.have_count(0)
          expect(
            browser_root.locator(".d-modal .sidebar-tags-form").filter(visible: true),
          ).not_to PlaywrightMatchers.have_count(0)

          PageObjects::Modals::SidebarEditTags.new
        end

        def edit_custom_section(name)
          name = name.parameterize

          if browser_root.locator("html.mobile-view").filter(visible: true).count != 0
            browser_root.locator(
              ".sidebar-section[data-section-name='#{name}'] button.sidebar-section-header-button",
            ).click
          else
            section_selector =
              ".sidebar-section[data-section-name='#{name}'] .sidebar-section-header-wrapper"

            browser_page.then { |pw_page| pw_page.locator(section_selector).hover }
            expect(
              browser_root.locator("button.sidebar-section-header-button").filter(visible: true),
            ).not_to PlaywrightMatchers.have_count(0)
            browser_root
              .locator("#{section_selector} button.sidebar-section-header-button")
              .filter(visible: true)
              .click
          end
        end

        private

        def section_link_present?(name, href: nil, active: false, target: nil, count: 1, present:)
          css_class = SIDEBAR_SECTION_LINK_SELECTOR + (active ? "--active" : "")
          links = browser_root.get_by_role("link").and(browser_root.locator(".#{css_class}"))
          links = links.and(browser_root.locator("[href=#{href.to_json}]")) if href
          links = links.and(browser_root.locator("[target=#{target.to_json}]")) if target
          links = links.filter(visible: true).filter(hasText: /^\s*#{Regexp.escape(name)}\s*$/)
          matcher = PlaywrightMatchers.have_count(count)
          present ? matcher.matches?(links) : matcher.does_not_match?(links)
        end

        def add_section_button_text
          I18n.t("js.sidebar.sections.custom.add")
        end

        def add_link_button_text
          I18n.t("js.sidebar.sections.custom.links.add")
        end

        def add_section_button_css
          ".sidebar-footer-actions-button.add-section"
        end
      end
    end
  end
end
