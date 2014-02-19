class AddLocaleToUser < ActiveRecord::Migration
  def change
    add_column :users, :locale, :string, limit: 10
  end
end
