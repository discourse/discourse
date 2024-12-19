# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminEmbeddingHostForm < PageObjects::Pages::Base
      def fill_in_allowed_hosts(url)
        form.field("host").fill_in(url)
        self
      end

      def fill_in_path_allow_list(path)
        form.field("allowed_paths").fill_in(path)
        self
      end

      def fill_in_category(category)
        dropdown = PageObjects::Components::SelectKit.new(".admin-embedding-host-form__category")
        dropdown.expand
        dropdown.search(category.name)
        dropdown.select_row_by_value(category.id)
        dropdown.collapse
        self
      end

      def fill_in_tags(tag)
        dropdown = PageObjects::Components::SelectKit.new(".admin-embedding-host-form__tags")
        dropdown.expand
        dropdown.search(tag.name)
        dropdown.select_row_by_value(tag.name)
        dropdown.collapse
        self
      end

      def fill_in_post_author(author)
        dropdown = PageObjects::Components::SelectKit.new(".admin-embedding-host-form__post_author")
        dropdown.expand
        dropdown.search(author.username)
        dropdown.select_row_by_value(author.username)
        dropdown.collapse
        self
      end

      def click_save
        form.submit
        expect(page).to have_css(".d-admin-table")
      end

      def form
        @form ||= PageObjects::Components::FormKit.new(".admin-embedding-host-form .form-kit")
      end
    end
  end
end
