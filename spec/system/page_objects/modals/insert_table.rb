# frozen_string_literal: true

module PageObjects
  module Modals
    class InsertTable < PageObjects::Modals::Base
      MODAL_SELECTOR = ".insert-table-modal"
      SPREADSHEET_TABLE_SELECTOR = "#{MODAL_SELECTOR} .jss_worksheet"

      def click_insert_table
        browser_root.locator("#{MODAL_SELECTOR} .btn-insert-table").filter(visible: true).click
      end

      def cancel
        browser_root
          .locator(
            "[id=#{I18n.t("js.cancel").to_s.to_json}], [name=#{I18n.t("js.cancel").to_s.to_json}]",
          )
          .or(browser_root.get_by_role("button", name: I18n.t("js.cancel")))
          .filter(visible: true)
          .click
      end

      def click_edit_reason
        browser_root.locator("#{MODAL_SELECTOR} .btn-edit-reason").filter(visible: true).click
      end

      def type_edit_reason(text)
        browser_root
          .locator("#{MODAL_SELECTOR} .edit-reason input")
          .filter(visible: true)
          .press_sequentially(text)
      end

      def find_cell(row, col)
        browser_root.locator(
          "#{SPREADSHEET_TABLE_SELECTOR} tbody tr[data-y='#{row}'] td[data-x='#{col}']",
        ).filter(visible: true)
      end

      def select_cell(row, col)
        find_cell(row, col).dblclick()
      end

      def type_in_cell(row, col, text)
        select_cell(row, col)
        cell = find_cell(row, col).locator("textarea").filter(visible: true)
        begin
          cell.press_sequentially(text)
          cell.press("Enter")
        end
      end

      def has_content_in_cell?(row, col, content)
        find_cell(row, col).inner_text.strip == content
      end
    end
  end
end
