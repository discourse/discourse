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

      def open_edit_tag
        find(".tag-name-wrapper .edit-tag").click
      end

      def fill_tag_name(new_name)
        find("#edit-name").fill_in(with: new_name)
      end

      def fill_tag_description(new_description)
        find("#edit-description").fill_in(with: new_description)
      end

      def save_edit
        find(".edit-controls .submit-edit").click
      end

      def cancel_edit
        find(".edit-controls .cancel-edit").click
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

      def tag_info
        find(".tag-info")
      end

      def tag_name_within_tag_info
        tag_info.find(".tag-name-wrapper .discourse-tag").text
      end

      def tag_description_within_tag_info
        tag_info.find(".tag-description-wrapper").text
      end

      def tags_dropdown
        PageObjects::Components::SelectKit.new(".select-kit.tag-drop")
      end
    end
  end
end
