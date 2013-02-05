class RemovePmReflections < ActiveRecord::Migration
  def up
    execute 'delete from topic_links where link_topic_id in (select id from topics where archetype = \'private_message\') '
  end

  def down
  end
end
