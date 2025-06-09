# frozen_string_literal: true

module PageObjects
  module Modals
    class SidebarSectionForm < PageObjects::Modals::Base
      def fill_name(name)
        fill_in "section-name", with: name
      end

      def fill_link(name, url, icon = "link")
        fill_in("link-name", with: name, match: :first)
        fill_in("link-url", with: url, match: :first)
        find(".sidebar-section-form-link .select-kit summary", match: :first).click
        fill_in("filter-input-search", with: icon, match: :first)
        page.execute_script("window.scrollBy(0,10000)") # this a workaround for subfolder where page UI is broken
        find(".select-kit-row.is-highlighted", match: :first).click
      end

      def mark_as_public
        find(".modal .mark-public").click
      end

      def remove_last_link
        all(".delete-link").last.click
      end

      def delete
        find("#delete-section").click
      end

      def confirm_delete
        find(".dialog-container .btn-danger").click
        closed?
      end

      def confirm_update
        find(".dialog-container .btn-primary").click
        closed?
      end

      def reset
        find(".reset-link").click
        find(".dialog-footer .btn-primary").click
        closed?
        self
      end

      def save
        find("#save-section").click
        self
      end

      def visible?
        page.has_css?(".sidebar-section-form-modal")
      end

      def closed?
        page.has_no_css?(".sidebar-section-form-modal")
      end

      def has_disabled_save?
        find_button("Save", disabled: true)
      end

      def has_enabled_save?
        find_button("Save", disabled: false)
      end

      def topics_link
        find(".draggable[data-link-name='Topics']")
      end

      def review_link
        find(".draggable[data-link-name='Review']")
      end
    end
  end
end
