# frozen_string_literal: true

class RemoveLengthConstrainFromTopicExcerpt < ActiveRecord::Migration[6.1]
  def up
    change_column :topics, :excerpt, :string, null: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
