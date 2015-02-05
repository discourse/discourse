class AddCustomTypeToUserHistories < ActiveRecord::Migration
  def change
    add_column :user_histories, :custom_type, :string
  end
end
