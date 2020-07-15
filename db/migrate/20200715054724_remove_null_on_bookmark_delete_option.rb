# frozen_string_literal: true

class RemoveNullOnBookmarkDeleteOption < ActiveRecord::Migration[6.0]
  def up
    DB.exec("UPDATE bookmarks SET delete_option = 0 WHERE delete_option IS NULL")
    change_column_default :bookmarks, :delete_option, 0
    change_column_null :bookmarks, :delete_option, false
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
