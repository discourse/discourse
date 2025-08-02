# frozen_string_literal: true

class MakeUserAuthTokenIndexUnique < ActiveRecord::Migration[4.2]
  def up
    remove_index :user_auth_tokens, [:auth_token]
    remove_index :user_auth_tokens, [:prev_auth_token]
    add_index :user_auth_tokens, [:auth_token], unique: true
    add_index :user_auth_tokens, [:prev_auth_token], unique: true
  end

  def down
    # no op, this should always have been unique
  end
end
