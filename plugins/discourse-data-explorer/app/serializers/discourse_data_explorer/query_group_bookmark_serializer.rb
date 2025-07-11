# frozen_string_literal: true

module ::DiscourseDataExplorer
  class QueryGroupBookmarkSerializer < UserBookmarkBaseSerializer
    def title
      fancy_title
    end

    def fancy_title
      data_explorer_query.name
    end

    def cooked
      data_explorer_query.description
    end

    def bookmarkable_user
      @bookmarkable_user ||= data_explorer_query.user
    end

    def bookmarkable_url
      "/g/#{data_explorer_query_group.group.name}/reports/#{data_explorer_query_group.query_id}"
    end

    def excerpt
      return nil unless cooked
      @excerpt ||= PrettyText.excerpt(cooked, 300, keep_emoji_images: true)
    end

    private

    def data_explorer_query
      data_explorer_query_group.query
    end

    def data_explorer_query_group
      object.bookmarkable
    end
  end
end
