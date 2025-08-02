# frozen_string_literal: true

class CreateQuestionAnswerComments < ActiveRecord::Migration[6.1]
  def change
    create_table :question_answer_comments do |t|
      t.integer :post_id, null: false
      t.integer :user_id, null: false
      t.text :raw, null: false
      t.text :cooked, null: false
      t.integer :cooked_version
      t.datetime :deleted_at
      t.integer :deleted_by_id

      t.timestamps
    end

    add_index :question_answer_comments, :post_id
    add_index :question_answer_comments, :user_id
    add_index :question_answer_comments, :deleted_by_id, where: "deleted_by_id IS NOT NULL"
  end
end
