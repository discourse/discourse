# frozen_string_literal: true

module Jobs
  class CreateRecentPostSearchIndexes < ::Jobs::Scheduled
    every 1.day

    REGULAR_POST_SEARCH_DATA_INDEX_NAME = "idx_recent_regular_post_search_data"

    def execute(_)
      create_recent_regular_post_search_index
    end

    private

    def create_recent_regular_post_search_index
      if !PostSearchData
           .where(private_message: false)
           .offset(SiteSetting.search_enable_recent_regular_posts_offset_size - 1)
           .limit(1)
           .exists?
        return
      end

      SiteSetting.search_recent_regular_posts_offset_post_id = regular_offset_post_id

      DB.exec(<<~SQL)
      DROP INDEX IF EXISTS temp_idx_recent_regular_post_search_data;
      SQL

      DB.exec(<<~SQL, post_id: SiteSetting.search_recent_regular_posts_offset_post_id)
      CREATE INDEX #{Rails.env.test? ? "" : "CONCURRENTLY"} temp_idx_recent_regular_post_search_data
      ON post_search_data USING GIN(search_data)
      WHERE NOT private_message AND post_id >= :post_id
      SQL

      DB.exec(<<~SQL)
      #{Rails.env.test? ? "" : "BEGIN;"}
      DROP INDEX IF EXISTS #{REGULAR_POST_SEARCH_DATA_INDEX_NAME};
      ALTER INDEX temp_idx_recent_regular_post_search_data RENAME TO #{REGULAR_POST_SEARCH_DATA_INDEX_NAME};
      #{Rails.env.test? ? "" : "COMMIT;"}
      SQL
    end

    def regular_offset_post_id
      PostSearchData
        .order("post_id DESC")
        .where(private_message: false)
        .offset(SiteSetting.search_recent_posts_size - 1)
        .limit(1)
        .pluck(:post_id)
        .first
    end
  end
end
