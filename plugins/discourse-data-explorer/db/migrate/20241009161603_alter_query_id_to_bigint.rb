# frozen_string_literal: true

class AlterQueryIdToBigint < ActiveRecord::Migration[7.1]
  def up
    change_column :data_explorer_query_groups, :query_id, :bigint
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
