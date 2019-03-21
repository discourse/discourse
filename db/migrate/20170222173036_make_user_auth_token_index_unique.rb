class MakeUserAuthTokenIndexUnique < ActiveRecord::Migration[4.2]
  def up
    remove_index :user_auth_tokens, %i[auth_token]
    remove_index :user_auth_tokens, %i[prev_auth_token]
    add_index :user_auth_tokens, %i[auth_token], unique: true
    add_index :user_auth_tokens, %i[prev_auth_token], unique: true
  end

  def down
    # no op, this should always have been unique
  end
end
