# frozen_string_literal: true

class AddTokenToInvites < ActiveRecord::Migration[6.0]
  def change
    add_column :invites, :email_token, :string
  end
end
