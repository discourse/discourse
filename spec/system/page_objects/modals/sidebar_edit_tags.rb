# frozen_string_literal: true

require_relative "sidebar_edit_navigation_modal"

module PageObjects
  module Modals
    class SidebarEditTags < SidebarEditNavigationModal
      def has_tag_checkboxes?(tags)
        expect(form).to have_text(
          tags.map { |tag| "#{tag.name} (#{tag.public_topic_count})" }.join("\n"),
          useInnerText: true,
        )
      end

      def has_no_tag_checkboxes?
        have_count(0).matches?(
          browser_root.locator(".sidebar-tags-form .sidebar-tags-form__tag").filter(visible: true),
        ) &&
          contain_text(
            [browser_text_pattern(I18n.t("js.sidebar.tags_form_modal.no_tags"))],
            useInnerText: true,
          ).matches?(
            browser_root.locator(".sidebar-tags-form .sidebar-tags-form__no-tags").filter(
              visible: true,
            ),
          )
      end

      def toggle_tag_checkbox(tag)
        browser_root
          .locator(
            ".sidebar-tags-form .sidebar-tags-form__tag[data-tag-name='#{tag.name}'] .sidebar-tags-form__input",
          )
          .filter(visible: true)
          .click

        self
      end

      def scroll_to_tag(tag)
        browser_page.evaluate(
          "function(arguments) { #{"document.querySelector('.sidebar-tags-form__tag[data-tag-name=\"#{tag.name}\"]').scrollIntoView()"} }",
          arg: [],
        )
      end

      private

      def form
        browser_root.locator(".sidebar-tags-form").filter(visible: true)
      end
    end
  end
end
