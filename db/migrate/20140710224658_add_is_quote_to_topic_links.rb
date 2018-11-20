class AddIsQuoteToTopicLinks < ActiveRecord::Migration[4.2]
  def up
    add_column :topic_links, :quote, :boolean, default: false, null: false

    # a primitive backfill, eventual rebake will catch missing
    execute "
    UPDATE topic_links
    SET quote = true
    WHERE id IN (
    SELECT l.id
      FROM topic_links l
      JOIN posts p ON p.id = l.post_id
      JOIN posts lp ON l.link_post_id = lp.id
      WHERE p.raw LIKE '%\[quote=%post:' ||
            lp.post_number::varchar || ',%topic:' ||
            lp.topic_id::varchar || '%\]%\[/quote]%'
    )"
  end

  def down
    remove_column :topic_links, :quote
  end
end
