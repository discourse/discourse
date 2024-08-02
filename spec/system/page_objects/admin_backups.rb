# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminBackups < PageObjects::Pages::Base
      def visit_page
        page.visit "/admin/backups"
        self
      end

      def click_tab(tab_name)
        case tab_name
        when "settings"
          find(".admin-backups-tabs__settings").click
        when "files"
          find(".admin-backups-tabs__files").click
        when "logs"
          find(".admin-backups-tabs__logs").click
        end
      end

      def has_backup_listed?(filename)
        page.has_css?(backup_row_selector(filename))
      end

      def has_no_backup_listed?(filename)
        page.has_no_css?(backup_row_selector(filename))
      end

      def download_backup(filename)
        find_backup_row(filename).find(".backup-item-row__download").click
      end

      def delete_backup(filename)
        find_backup_row(filename).find(".backup-item-menu-trigger").click
        find(".backup-item-menu-content").find(".backup-item-row__delete").click
      end

      def find_backup_row(filename)
        find(backup_row_selector(filename))
      end

      def backup_row_selector(filename)
        ".admin-backups-list .backup-item-row[data-backup-filename='#{filename}']"
      end

      def toggle_read_only
        find(".admin-backups__toggle-read-only").click
      end
    end
  end
end
