# frozen_string_literal: true

module ImportScripts::PhpBB3
  class BookmarkImporter
    def map_bookmark(row)
      {
        user_id: row[:user_id],
        post_id: row[:topic_first_post_id]
      }
    end
  end
end
