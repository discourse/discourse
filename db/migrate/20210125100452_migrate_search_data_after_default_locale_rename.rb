# frozen_string_literal: true

class MigrateSearchDataAfterDefaultLocaleRename < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    %w[category tag topic user].each { |model| fix_search_data(model) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def fix_search_data(model)
    key = "#{model}_id"
    table = "#{model}_search_data"

    puts "Migrating #{table} to new locale."

    sql = <<~SQL
      UPDATE #{table}
         SET locale = 'en'
       WHERE #{key} IN (
              SELECT #{key}
                FROM #{table}
               WHERE locale = 'en_US'
               LIMIT 100000
           )
    SQL

    loop do
      count = execute(sql).cmd_tuples
      break if count == 0
      puts "Migrated #{count} rows of #{table} to new locale."
    end
  end
end
