# frozen_string_literal: true

require 'migration/table_dropper'

class DropUnusedAuthTablesAgain < ActiveRecord::Migration[5.2]
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
