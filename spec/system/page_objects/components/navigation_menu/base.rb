# frozen_string_literal: true

module PageObjects
  module Components
    module NavigationMenu
      class Base < PageObjects::Components::Base
        SIDEBAR_SECTION_LINK_SELECTOR = "sidebar-section-link"

        def visible?
          has_css?("#d-sidebar.sidebar-container")
        end

        def hidden?
          has_no_css?("#d-sidebar.sidebar-container")
        end

        def community_section
          find_section("community")
        end

        def find_section(name)
          find(sidebar_section_selector(name))
        end

        def click_section_header(name)
          find("#{sidebar_section_selector(name)} .sidebar-section-header").click
        end

        def click_section_link(name)
          find(".#{SIDEBAR_SECTION_LINK_SELECTOR}", text: name).click
        end

        def click_link_in_section(section_name, link_name)
          find_section(section_name.parameterize).find(
            ".#{SIDEBAR_SECTION_LINK_SELECTOR}[data-link-name=\"#{link_name.parameterize}\"]",
          ).click
        end

        def has_one_active_section_link?
          has_css?(".#{SIDEBAR_SECTION_LINK_SELECTOR}--active", count: 1)
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

        def has_section?(name)
          has_css?(".sidebar-sections [data-section-name='#{name.parameterize}']")
        end

        def has_no_section?(name)
          has_no_css?(".sidebar-sections [data-section-name='#{name.parameterize}']")
        end

        def has_section_expanded?(name)
          has_css?("#{sidebar_section_selector(name)}.sidebar-section--expanded")
        end

        def has_section_collapsed?(name)
          has_css?("#{sidebar_section_selector(name)}.sidebar-section--collapsed")
        end

        def switch_to_chat
          find(".sidebar__panel-switch-button[data-key='chat']").click
        end

        def switch_to_main
          find(".sidebar__panel-switch-button[data-key='main']").click
        end

        def has_switch_button?(key = nil)
          if key
            page.has_css?(".sidebar__panel-switch-button[data-key='#{key.parameterize}']")
          else
            page.has_css?(".sidebar__panel-switch-button")
          end
        end

        def has_no_switch_button?(key = nil)
          if key
            page.has_no_css?(".sidebar__panel-switch-button[data-key='#{key.parameterize}']")
          else
            page.has_no_css?(".sidebar__panel-switch-button")
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
            all(
              ".sidebar-section[data-section-name='tags'] .sidebar-section-link-wrapper[data-tag-name]",
              count: tag_names.length,
            )

          expect(tag_section_links.map(&:text)).to eq(tag_names)
        end

        def has_tag_section_link_with_title?(tag, title)
          section_link =
            find(
              ".sidebar-section[data-section-name='tags'] .sidebar-section-link-wrapper[data-tag-name='#{tag.name}'] .sidebar-section-link",
            )

          expect(section_link["title"]).to eq(title)
        end

        def find_section_link(name)
          find(".#{SIDEBAR_SECTION_LINK_SELECTOR}[data-link-name='#{name}']")
        end

        def primary_section_links(slug)
          all("[data-section-name='#{slug}'] .sidebar-section-link-wrapper").map(&:text)
        end

        def primary_section_icons(slug)
          all("[data-section-name='#{slug}'] .sidebar-section-link-wrapper use").map do |icon|
            icon[:href].delete_prefix("#")
          end
        end

        def has_category_section_link?(category)
          page.has_link?(category.name, class: "sidebar-section-link")
        end

        def click_add_section_button
          click_button(add_section_button_text)
        end

        def click_add_link_button
          click_button(add_link_button_text)
        end

        def has_no_add_section_button?
          has_no_css?(add_section_button_css)
        end

        def has_add_section_button?
          has_css?(add_section_button_css)
        end

        def click_edit_categories_button
          within(".sidebar-section[data-section-name='categories']") do
            click_button(class: "sidebar-section-header-button", visible: false)
          end

          expect(page).to have_css(".d-modal:not(.is-animating)")

          PageObjects::Modals::SidebarEditCategories.new
        end

        def click_edit_tags_button
          within(".sidebar-section[data-section-name='tags']") do
            click_button(class: "sidebar-section-header-button", visible: false)
          end

          expect(page).to have_css(".d-modal:not(.is-animating)")
          expect(page).to have_css(".d-modal .sidebar-tags-form")

          PageObjects::Modals::SidebarEditTags.new
        end

        def edit_custom_section(name)
          name = name.parameterize

          if page.has_css?("html.mobile-view", wait: 0)
            find(
              ".sidebar-section[data-section-name='#{name}'] button.sidebar-section-header-button",
              visible: false,
            ).click
          else
            find(".sidebar-section[data-section-name='#{name}']").hover
            find(
              ".sidebar-section[data-section-name='#{name}'] button.sidebar-section-header-button",
            ).click
          end
        end

        private

        def sidebar_section_selector(name)
          ".sidebar-section[data-section-name='#{name}']"
        end

        def section_link_present?(name, href: nil, active: false, target: nil, count: 1, present:)
          attributes = { exact_text: name }
          attributes[:href] = href if href
          attributes[:class] = SIDEBAR_SECTION_LINK_SELECTOR
          attributes[:class] += "--active" if active
          attributes[:target] = target if target
          attributes[:count] = count
          page.public_send(present ? :has_link? : :has_no_link?, **attributes)
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
