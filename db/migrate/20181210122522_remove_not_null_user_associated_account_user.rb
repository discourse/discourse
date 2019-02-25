class RemoveNotNullUserAssociatedAccountUser < ActiveRecord::Migration[5.2]
  def change
    begin
      Migration::SafeMigrate.disable!
      change_column_null :user_associated_accounts, :user_id, true
    ensure
      Migration::SafeMigrate.enable!
    end
  end
end
