class MigrateWarningTopicSubtypes < ActiveRecord::Migration[4.2]
  def change
    execute "UPDATE topics AS t
              SET subtype = 'moderator_warning'
              FROM warnings AS w
              WHERE w.topic_id = t.id"
  end
end
