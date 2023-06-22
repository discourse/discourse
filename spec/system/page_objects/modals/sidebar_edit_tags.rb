# frozen_string_literal: true

require_relative "sidebar_edit_navigation_modal"

module PageObjects
  module Modals
    class SidebarEditTags < SidebarEditNavigationModal
      def closed?
        has_no_css?(".sidebar-tags-form-modal")
      end

      def has_right_title?(title)
        has_css?(".sidebar-tags-form-modal #discourse-modal-title", text: title)
      end

      def has_tag_checkboxes?(tags)
        tag_names = tags.map(&:name)

        has_css?(".sidebar-tags-form-modal .sidebar-tags-form__tag", count: tag_names.length) &&
          all(".sidebar-tags-form-modal .sidebar-tags-form__tag").all? do |row|
            tag_names.include?(row["data-tag-name"].to_s)
          end
      end

      def has_no_tag_checkboxes?
        has_no_css?(".sidebar-tags-form-modal .sidebar-tags-form__tag") &&
          has_css?(
            ".sidebar-tags-form-modal .sidebar-tags-form__no-tags",
            text: I18n.t("js.sidebar.tags_form_modal.no_tags"),
          )
      end

      def toggle_tag_checkbox(tag)
        find(
          ".sidebar-tags-form-modal .sidebar-tags-form__tag[data-tag-name='#{tag.name}'] .sidebar-tags-form__input",
        ).click

        self
      end
    end
  end
end
