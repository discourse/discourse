# frozen_string_literal: true

module PageObjects
  module Components
    class BoardsColumn < PageObjects::Components::Base
      def initialize(title: nil, id: nil)
        @title = title
        @id = id

        if @title.blank? && @id.blank?
          raise "Column must be initialized with either a title or an id"
        end
      end

      def find_by_title(title)
        find(".discourse-boards-column__title", text: /#{Regexp.escape(title)}/i).ancestor(
          ".discourse-boards-column",
        )
      end

      def find_by_id(id)
        find(".discourse-boards-column[data-column-id='#{id}']")
      end

      def find_column
        if @title
          find_by_title(@title)
        elsif @id
          find_by_id(@id)
        end
      end

      def exists?
        find_column
        true
      end

      def menu
        PageObjects::Components::DMenu.new(
          find_column.find(".discourse-boards-column__menu-trigger", visible: :all),
        )
      end

      def open_menu
        menu.expand
        self
      end

      def click_delete
        menu.option(".discourse-boards-column__menu-delete").click
      end

      def has_color?(color)
        color = color.delete_prefix("#")
        find_column["style"].include?("--discourse-boards-column-color: ##{color};")
      end
    end
  end
end
