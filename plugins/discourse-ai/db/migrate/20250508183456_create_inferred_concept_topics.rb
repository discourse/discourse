# frozen_string_literal: true

class CreateInferredConceptTopics < ActiveRecord::Migration[7.0]
  def change
    create_table :inferred_concept_topics, id: false do |t|
      t.bigint :inferred_concept_id
      t.bigint :topic_id
      t.timestamps
    end

    add_index :inferred_concept_topics,
              %i[topic_id inferred_concept_id],
              unique: true,
              name: "index_inferred_concept_topics_uniqueness"

    add_index :inferred_concept_topics, :inferred_concept_id
  end
end
