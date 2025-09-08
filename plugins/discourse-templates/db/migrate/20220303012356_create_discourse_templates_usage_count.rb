# frozen_string_literal: true

class CreateDiscourseTemplatesUsageCount < ActiveRecord::Migration[6.1]
  def up
    create_table :discourse_templates_usage_count do |t|
      t.integer :topic_id, null: false
      t.integer :usage_count, null: false, default: 0

      t.timestamps
    end
    add_index :discourse_templates_usage_count, :topic_id, unique: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
