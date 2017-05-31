class AddThemeKeySeqToUserOptions < ActiveRecord::Migration
  def change
    add_column :user_options, :theme_key_seq, :integer, null: false, default: 0
  end
end
