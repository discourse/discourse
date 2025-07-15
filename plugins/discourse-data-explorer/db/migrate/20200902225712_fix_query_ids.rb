# frozen_string_literal: true

class FixQueryIds < ActiveRecord::Migration[6.0]
  def up
    Rake::Task["data_explorer:fix_query_ids"].invoke
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
