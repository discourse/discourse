class RemoveTopicResponseActions < ActiveRecord::Migration[4.2]
  def up
    # 2 notes:
    #   migrations should never use the object model to run sql, otherwise they are a time bomb
    #   this action type is not valid, we log a "response" action type anyway due to the watch implementation, its a relic.
    #
    # There is an open question about we should keep stuff in the user stream on the user page, even if a topic is unwatched
    #  Eg: I am not watching a topic I created, when somebody responds to the topic should I be notified on the user page?
    execute 'delete from user_actions where action_type = 8'
  end

  def down
  end
end
