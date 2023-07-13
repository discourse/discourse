# frozen_string_literal: true

module PageObjects
  module Pages
    class Tag < PageObjects::Pages::Base
      def visit_tag(tag)
        page.visit "/tag/#{tag.name}"
        self
      end

      def tag_info_btn
        find("#show-tag-info")
      end

      def edit_synonyms_btn
        find("#edit-synonyms")
      end

      def add_synonym_btn
        find(".add-synonyms .ok")
      end

      def confirm_synonym_btn
        find(".dialog-footer .btn-primary")
      end

      def add_synonyms_dropdown
        PageObjects::Components::SelectKit.new("#add-synonyms")
      end

      def search_tags(query)
        add_synonyms_dropdown.search(query)
      end

      def select_tag(value: nil, index: nil, name: nil)
        if value
          add_synonyms_dropdown.select_row_by_value(value)
        elsif name
          add_synonyms_dropdown.select_row_by_name(name)
        elsif index
          add_synonyms_dropdown.select_row_by_index(index)
        end
      end

      def tag_box(tag)
        find(".tag-box div[data-tag-name='#{tag}']")
      end
    end
  end
end
