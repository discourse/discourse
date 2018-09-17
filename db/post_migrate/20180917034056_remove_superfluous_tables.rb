require 'migration/table_dropper'

class RemoveSuperfluousTables < ActiveRecord::Migration[5.2]
  def up
    %i{
      category_featured_users
      versions
      topic_status_updates
    }.each do |table|
      Migration::TableDropper.execute_drop(table)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
