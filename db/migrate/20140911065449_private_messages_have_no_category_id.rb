class PrivateMessagesHaveNoCategoryId < ActiveRecord::Migration[4.2]
  def up
    execute "UPDATE topics SET category_id = NULL WHERE category_id IS NOT NULL AND archetype = \'private_message\'"
    execute "ALTER TABLE topics ADD CONSTRAINT pm_has_no_category CHECK (category_id IS NULL OR archetype <> 'private_message')"
  end
  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
