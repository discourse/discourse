class AddCustomMessageToInvite < ActiveRecord::Migration
  def change
    add_column :invites, :custom_message, :text
  end
end
