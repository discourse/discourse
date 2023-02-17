# frozen_string_literal: true

module PageObjects
  module Modals
    class SidebarSectionForm < PageObjects::Modals::Base
      def fill_name(name)
        fill_in "section-name", with: name
      end

      def fill_link(name, url)
        fill_in "link-name", with: name, match: :first
        fill_in "link-url", with: url, match: :first
      end

      def remove_last_link
        all(".delete-link").last.click
      end

      def delete
        find("#delete-section").click
      end

      def confirm_delete
        find(".dialog-container .btn-primary").click
      end

      def save
        find("#save-section").click
      end

      def visible?
        page.has_css?(".sidebar-section-form-modal")
      end

      def has_disabled_save?
        find_button("Save", disabled: true)
      end
      def has_enabled_save?
        find_button("Save", disabled: false)
      end
    end
  end
end
