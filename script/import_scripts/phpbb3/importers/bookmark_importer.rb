# frozen_string_literal: true

module ImportScripts::PhpBB3
  class BookmarkImporter
    def initialize(settings)
      @settings = settings
    end

    def map_bookmark(row)
      {
        user_id: @settings.prefix(row[:user_id]),
        post_id: @settings.prefix(row[:topic_first_post_id]),
      }
    end
  end
end
