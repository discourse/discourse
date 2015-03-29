class CorrectUsernameSearch < ActiveRecord::Migration
  def up
    execute "update user_search_data
              set search_data = TO_TSVECTOR('simple', username_lower || ' ' || lower(name))
            from users
            where users.id = user_search_data.user_id"
  end

  def down
  end
end
