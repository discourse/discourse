class AddLastErrorTextToRemoteThemes < ActiveRecord::Migration[5.2]
  def change
    add_column :remote_themes, :last_error_text, :text
  end
end
