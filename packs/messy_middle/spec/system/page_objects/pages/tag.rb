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

      def add_synonyms_select_field
        find("#add-synonyms")
      end

      def search_tags(search)
        find("#add-synonyms-filter input").fill_in(with: search)
      end

      def has_search_result?(tag)
        page.has_selector?(".select-kit-row[data-name='#{tag}']")
      end

      def search_result(index)
        find(".select-kit-collection li:nth-child(#{index})")
      end

      def tag_box(tag)
        find(".tag-box div[data-tag-name='#{tag}']")
      end
    end
  end
end
