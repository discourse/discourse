# frozen_string_literal: true

class BackfillOutboundMessageId < ActiveRecord::Migration[7.0]
  def up
    # best effort backfill, we don't care about years worth of message_id
    # preservation
    #
    # we also don't need to backfill outbound_message_id for posts that
    # do _not_ have an incoming email linked, since that will be backfilled
    # at runtime if it is missing
    sql_query = <<~SQL
      UPDATE posts
      SET outbound_message_id = ie.message_id
      FROM incoming_emails AS ie
      WHERE ie.post_id = posts.id
        AND posts.created_at >= :one_year_ago
        AND posts.outbound_message_id IS NULL
    SQL
    DB.exec(sql_query, one_year_ago: 1.year.ago)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
