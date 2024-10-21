# frozen_string_literal: true

class DropCategoryRequiredTagGroupColumns < ActiveRecord::Migration[6.1]
  DROPPED_COLUMNS = { categories: %i[required_tag_group_id min_tags_from_required_group] }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
