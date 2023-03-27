# frozen_string_literal: true

class RemoveUserOptionLastEmailedAt < ActiveRecord::Migration[7.0]
  def change
    remove_column :user_options, :last_emailed_for_chat, :datetime
  end
end
