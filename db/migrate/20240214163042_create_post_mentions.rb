# frozen_string_literal: true

class CreatePostMentions < ActiveRecord::Migration[7.0]
  def change
    create_table :post_mentions do |t|
      t.references :post, null: false
      t.references :mention, polymorphic: true, null: false
      t.timestamps
    end

    add_index :post_mentions,
              %i[post_id mention_type mention_id],
              unique: true,
              name: "index_post_mentions_on_post_and_mention"
  end
end
