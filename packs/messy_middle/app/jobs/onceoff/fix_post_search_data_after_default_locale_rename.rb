# frozen_string_literal: true

module Jobs
  class FixPostSearchDataAfterDefaultLocaleRename < ::Jobs::Onceoff
    def execute_onceoff(args)
      return if SearchIndexer::POST_INDEX_VERSION != 4

      sql = <<~SQL
        UPDATE post_search_data
           SET locale = 'en'
         WHERE post_id IN (
                SELECT post_id
                  FROM post_search_data
                 WHERE locale = 'en_US'
                 LIMIT 100000
             )
      SQL

      loop { break if DB.exec(sql) == 0 }
    end
  end
end
