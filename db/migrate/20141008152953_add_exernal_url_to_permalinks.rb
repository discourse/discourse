class AddExernalUrlToPermalinks < ActiveRecord::Migration
  def change
    add_column :permalinks, :external_url, :string, limit: 1000
  end
end
