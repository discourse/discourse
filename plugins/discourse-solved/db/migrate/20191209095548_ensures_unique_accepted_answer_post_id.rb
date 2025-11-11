# frozen_string_literal: true

class EnsuresUniqueAcceptedAnswerPostId < ActiveRecord::Migration[5.2]
  def change
    execute <<~SQL
      DELETE FROM topic_custom_fields AS tcf1
      USING topic_custom_fields AS tcf2
      WHERE tcf1.id > tcf2.id AND
         tcf1.topic_id = tcf2.topic_id AND
         tcf1.name = tcf2.name AND
         tcf1.name = 'accepted_answer_post_id'
    SQL

    add_index :topic_custom_fields,
              :topic_id,
              name: :idx_topic_custom_fields_accepted_answer,
              unique: true,
              where: "name = 'accepted_answer_post_id'"
  end
end
