# frozen_string_literal: true

class AddScopeToEmailToken < ActiveRecord::Migration[6.1]
  def up
    add_column :email_tokens, :scope, :integer
  end

  def down
    drop_column :email_tokens, :scope, :integer
  end
end
