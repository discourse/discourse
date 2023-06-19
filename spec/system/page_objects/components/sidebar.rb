# frozen_string_literal: true

module PageObjects
  module Components
    class Sidebar < PageObjects::Components::Base
      def visible?
        page.has_css?("#d-sidebar")
      end

      def not_visible?
        page.has_no_css?("#d-sidebar")
      end

      def has_category_section_link?(category)
        page.has_link?(category.name, class: "sidebar-section-link")
      end

      def click_add_section_button
        click_button(add_section_button_text)
      end

      def has_no_add_section_button?
        page.has_no_button?(add_section_button_text)
      end

      def click_edit_categories_button
        within(".sidebar-section[data-section-name='categories']") do
          click_button(class: "sidebar-section-header-button", visible: false)
        end

        PageObjects::Modals::SidebarEditCategories.new
      end

      def edit_custom_section(name)
        find(".sidebar-section[data-section-name='#{name.parameterize}']").hover

        find(
          ".sidebar-section[data-section-name='#{name.parameterize}'] button.sidebar-section-header-button",
        ).click
      end

      SIDEBAR_SECTION_LINK_SELECTOR = "sidebar-section-link"

      def click_section_link(name)
        find(".#{SIDEBAR_SECTION_LINK_SELECTOR}", text: name).click
      end

      def has_one_active_section_link?
        has_css?(".#{SIDEBAR_SECTION_LINK_SELECTOR}--active", count: 1)
      end

      def has_section_link?(name, href: nil, active: false)
        section_link_present?(name, href: href, active: active, present: true)
      end

      def has_no_section_link?(name, href: nil, active: false)
        section_link_present?(name, href: href, active: active, present: false)
      end

      def custom_section_modal_title
        find("#discourse-modal-title")
      end

      SIDEBAR_WRAPPER_SELECTOR = ".sidebar-wrapper"

      def has_section?(name)
        find(SIDEBAR_WRAPPER_SELECTOR).has_button?(name)
      end

      def has_categories_section?
        has_section?("Categories")
      end

      def has_no_section?(name)
        find(SIDEBAR_WRAPPER_SELECTOR).has_no_button?(name)
      end

      def primary_section_links(slug)
        all("[data-section-name='#{slug}'] .sidebar-section-link-wrapper").map(&:text)
      end

      def primary_section_icons(slug)
        all("[data-section-name='#{slug}'] .sidebar-section-link-wrapper use").map do |icon|
          icon[:href].delete_prefix("#")
        end
      end

      private

      def section_link_present?(name, href: nil, active: false, present:)
        attributes = { exact_text: name }
        attributes[:href] = href if href
        attributes[:class] = SIDEBAR_SECTION_LINK_SELECTOR
        attributes[:class] += "--active" if active
        page.public_send(present ? :has_link? : :has_no_link?, **attributes)
      end

      def add_section_button_text
        I18n.t("js.sidebar.sections.custom.add")
      end
    end
  end
end
