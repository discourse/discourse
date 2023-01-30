# frozen_string_literal: true

class DeleteMisconfiguredEmbeddableHosts < ActiveRecord::Migration[7.0]
  def up
    execute(<<~SQL)
      DELETE FROM embeddable_hosts eh1
      WHERE eh1.id IN (
        SELECT eh2.id FROM embeddable_hosts eh2
        LEFT JOIN categories ON categories.id = eh2.category_id
        WHERE eh2.category_id IS NOT NULL
        AND categories.id IS NULL
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
