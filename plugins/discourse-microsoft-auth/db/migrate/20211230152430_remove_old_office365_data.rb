# frozen_string_literal: true
class RemoveOldOffice365Data < ActiveRecord::Migration[6.1]
  def up
    execute "DELETE FROM oauth2_user_infos WHERE provider = 'microsoft_office365'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
