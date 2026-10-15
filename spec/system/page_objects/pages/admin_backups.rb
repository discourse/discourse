# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminBackups < AdminBase
      def visit_page
        browser_page.goto("/admin/backups").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def has_backup_listed?(filename)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(backup_row_selector(filename)).filter(visible: true),
        )
      end

      def has_no_backup_listed?(filename)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(backup_row_selector(filename)).filter(visible: true),
        )
      end

      def open_upload_backup_modal
        browser_root.locator(".admin-backups__start").filter(visible: true).click
      end

      def download_backup(filename)
        find_backup_row(filename)
          .locator(row_button_selector("download"))
          .filter(visible: true)
          .click
      end

      def expand_backup_row_menu(filename)
        find_backup_row(filename).locator(".backup-item-menu-trigger").filter(visible: true).click
      end

      def delete_backup(filename)
        expand_backup_row_menu(filename)
        browser_root
          .locator(".backup-item-menu-content")
          .filter(visible: true)
          .locator(row_button_selector("delete"))
          .filter(visible: true)
          .click
      end

      def restore_backup(filename)
        expand_backup_row_menu(filename)
        browser_root
          .locator(".backup-item-menu-content")
          .filter(visible: true)
          .locator(row_button_selector("restore"))
          .filter(visible: true)
          .click
      end

      def find_backup_row(filename)
        browser_root.locator(backup_row_selector(filename)).filter(visible: true)
      end

      def backup_row_selector(filename)
        ".admin-backups-list .backup-item-row[data-backup-filename='#{filename}']"
      end

      def row_button_selector(button_name)
        ".backup-item-row__#{button_name}"
      end

      def toggle_read_only
        browser_root.locator(".admin-backups__toggle-read-only").filter(visible: true).click
      end

      def has_no_read_only_button?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".admin-backups__toggle-read-only").filter(visible: true),
        )
      end

      def has_no_backup_button?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".admin-backups__start").filter(visible: true),
        )
      end

      def has_no_backup_item_more_menu?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".backup-item-menu-trigger").filter(visible: true),
        )
      end
    end
  end
end
