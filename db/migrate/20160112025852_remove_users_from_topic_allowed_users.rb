class RemoveUsersFromTopicAllowedUsers < ActiveRecord::Migration[4.2]

  # historically we added admins automatically to a message if they
  # responded, despite them being in the group the message is targetted at
  # this causes inbox bloat for pretty much no reason
  def up
    sql = <<SQL
    DELETE FROM topic_allowed_users tu
    USING topic_allowed_groups tg
    JOIN group_users gu ON gu.group_id = tg.group_id
    WHERE tu.user_id = gu.user_id AND tg.topic_id = tu.topic_id
SQL

    execute sql
  end

  def down
    # can not be reversed but can be replayed if needed
  end
end
