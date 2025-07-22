# frozen_string_literal: true

class CreateInferredConceptPosts < ActiveRecord::Migration[7.0]
  def change
    create_table :inferred_concept_posts, id: false do |t|
      t.bigint :inferred_concept_id
      t.bigint :post_id
      t.timestamps
    end

    add_index :inferred_concept_posts,
              %i[post_id inferred_concept_id],
              unique: true,
              name: "index_inferred_concept_posts_uniqueness"

    add_index :inferred_concept_posts, :inferred_concept_id
  end
end
