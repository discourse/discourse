require 'migration/table_dropper'

class DropUnusedAuthTables < ActiveRecord::Migration[5.2]
  def change
    def up
      %i{
        facebook_user_infos
        twitter_user_infos
      }.each do |table|
        Migration::TableDropper.execute_drop(table)
      end
    end

    def down
      raise ActiveRecord::IrreversibleMigration
    end
  end
end
