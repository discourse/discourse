# frozen_string_literal: true
class AddCoveringIndexToBrowserPageviewEvents < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    if index_exists?(
         :browser_pageview_events,
         %i[session_id created_at],
         name: "idx_bpe_session_created_at_covering",
         include: %i[user_id score],
         valid: true,
       )
      return
    end

    remove_index :browser_pageview_events,
                 name: "idx_bpe_session_created_at_covering",
                 algorithm: :concurrently,
                 if_exists: true

    add_index :browser_pageview_events,
              %i[session_id created_at],
              name: "idx_bpe_session_created_at_covering",
              include: %i[user_id score],
              algorithm: :concurrently
  end

  def down
    remove_index :browser_pageview_events,
                 name: "idx_bpe_session_created_at_covering",
                 algorithm: :concurrently,
                 if_exists: true
  end
end
