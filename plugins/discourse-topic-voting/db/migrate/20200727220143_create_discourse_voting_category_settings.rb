# frozen_string_literal: true

class CreateDiscourseVotingCategorySettings < ActiveRecord::Migration[6.0]
  def up
    create_table :discourse_voting_category_settings do |t|
      t.integer :category_id
      t.timestamps
    end
    add_index :discourse_voting_category_settings, :category_id, unique: true

    DB.exec <<~SQL
      INSERT INTO discourse_voting_category_settings(category_id, created_at, updated_at)
      SELECT category_id, created_at, updated_at
      FROM category_custom_fields
      WHERE name = 'enable_topic_voting' and value = 'true'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
