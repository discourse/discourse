class RemoveEnforceSquareEmoji < ActiveRecord::Migration[5.2]
  def change
    execute "DELETE FROM site_settings WHERE name = 'enforce_square_emoji'"
  end
end
