# frozen_string_literal: true

class IndexEmailTokens < ActiveRecord::Migration[4.2]
  def change
    add_index :email_tokens, [:user_id]
  end
end
