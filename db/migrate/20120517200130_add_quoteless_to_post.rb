class AddQuotelessToPost < ActiveRecord::Migration
  def change
    add_column :posts, :quoteless, :boolean, default: false
  end
end
