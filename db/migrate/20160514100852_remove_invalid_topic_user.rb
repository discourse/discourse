class RemoveInvalidTopicUser < ActiveRecord::Migration
  def up
    execute <<-SQL
      DELETE FROM topic_users
       USING topic_users tu
   LEFT JOIN users u ON u.id = tu.user_id
       WHERE u.id IS NULL
         AND topic_users.id = tu.id
    SQL
  end

  def down
  end
end
