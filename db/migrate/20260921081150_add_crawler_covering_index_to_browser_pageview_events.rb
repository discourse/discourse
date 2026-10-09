# frozen_string_literal: true
class AddCrawlerCoveringIndexToBrowserPageviewEvents < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    if index_exists?(
         :browser_pageview_events,
         :created_at,
         name: "idx_bpe_crawler_created_at_covering",
         include: %i[topic_id user_id ip_address],
         valid: true,
       )
      return
    end

    remove_index :browser_pageview_events,
                 name: "idx_bpe_crawler_created_at_covering",
                 algorithm: :concurrently,
                 if_exists: true

    add_index :browser_pageview_events,
              :created_at,
              name: "idx_bpe_crawler_created_at_covering",
              include: %i[topic_id user_id ip_address],
              where: "score > 55",
              algorithm: :concurrently
  end

  def down
    remove_index :browser_pageview_events,
                 name: "idx_bpe_crawler_created_at_covering",
                 algorithm: :concurrently,
                 if_exists: true
  end
end
