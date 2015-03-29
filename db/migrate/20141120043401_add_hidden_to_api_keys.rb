class AddHiddenToApiKeys < ActiveRecord::Migration
  def change
    change_table :api_keys do |t|
      t.boolean :hidden, null: false, default: false
    end
  end
end
