class AddThemeKeySeqToUserOptions < ActiveRecord::Migration[4.2]
  def change
    add_column :user_options, :theme_key_seq, :integer, null: false, default: 0
  end
end
