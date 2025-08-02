# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminEmbeddingPostsAndTopics < PageObjects::Pages::Base
      def fill_in_embed_by_username(author)
        dropdown =
          PageObjects::Components::SelectKit.new(
            ".admin-embedding-posts-and-topics-form__embed_by_username",
          )
        dropdown.expand
        dropdown.search(author.username)
        dropdown.select_row_by_value(author.username)
        dropdown.collapse
        self
      end

      def click_save
        form = PageObjects::Components::FormKit.new(".admin-embedding .form-kit")
        form.submit
      end
    end
  end
end
