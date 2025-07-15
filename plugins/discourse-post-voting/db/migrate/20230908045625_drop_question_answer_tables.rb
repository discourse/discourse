# frozen_string_literal: true

require "migration/table_dropper"

class DropQuestionAnswerTables < ActiveRecord::Migration[7.0]
  def up
    if table_exists?(:question_answer_votes)
      Migration::TableDropper.execute_drop(:question_answer_votes)
    end

    if table_exists?(:question_answer_comments)
      Migration::TableDropper.execute_drop(:question_answer_comments)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
