# frozen_string_literal: true

class AddQuotedPosts < ActiveRecord::Migration[4.2]
  def change
    create_table :quoted_posts do |t|
      t.integer :post_id, null: false
      t.integer :quoted_post_id, null: false
      t.timestamps null: false
    end

    add_index :quoted_posts, [:post_id, :quoted_post_id], unique: true
    add_index :quoted_posts, [:quoted_post_id, :post_id], unique: true

    # NOTE this can be done in pg but too much of a headache
    id = 0
    while id = backfill_batch(id, 1000); end
  end

  def backfill_batch(start_id, batch_size)

    results = execute <<SQL
    SELECT id, cooked
    FROM posts
    WHERE raw like '%quote=%' AND id > #{start_id}
    ORDER BY id
    LIMIT #{batch_size}
SQL

    max_id = nil

    results.each do |row|
      post_id, max_id = row["id"].to_i
      doc = Nokogiri::HTML.fragment(row["cooked"])

      uniq = {}

      doc.css("aside.quote[data-topic]").each do |a|
        topic_id = a['data-topic'].to_i
        post_number = a['data-post'].to_i

        next if uniq[[topic_id, post_number]]
        uniq[[topic_id, post_number]] = true

        execute "INSERT INTO quoted_posts(post_id, quoted_post_id, created_at, updated_at)
                 SELECT #{post_id}, id, created_at, updated_at
                 FROM posts
                 WHERE post_number = #{post_number} AND
                       topic_id = #{topic_id}"
      end
    end

    max_id
  end
end
