# frozen_string_literal: true

module PageObjects
  module Modals
    class InsertTable < PageObjects::Modals::Base
      MODAL_SELECTOR = ".insert-table-modal"
      SPREADSHEET_TABLE_SELECTOR = "#{MODAL_SELECTOR} .jexcel".freeze

      def click_insert_table
        find("#{MODAL_SELECTOR} .btn-insert-table").click
      end

      def cancel
        click_button(I18n.t("js.cancel"))
      end

      def click_edit_reason
        find("#{MODAL_SELECTOR} .btn-edit-reason").click
      end

      def type_edit_reason(text)
        find("#{MODAL_SELECTOR} .edit-reason input").send_keys(text)
      end

      def find_cell(row, col)
        find("#{SPREADSHEET_TABLE_SELECTOR} tbody tr[data-y='#{row}'] td[data-x='#{col}']")
      end

      def select_cell(row, col)
        find_cell(row, col).double_click
      end

      def type_in_cell(row, col, text)
        select_cell(row, col)
        cell = find_cell(row, col).find("textarea")
        cell.send_keys(text, :return)
      end

      def has_content_in_cell?(row, col, content)
        find_cell(row, col).text == content
      end
    end
  end
end
