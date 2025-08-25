# frozen_string_literal: true
class AddTypeToTopicTimer < ActiveRecord::Migration[8.0]
  def change
    add_column :topic_timers, :type, :string, null: false, default: "TopicTimer"
    rename_column :topic_timers, :topic_id, :timerable_id

    reversible do |dir|
      dir.up do
        change_column_null :topic_timers, :execute_at, true

        Category
          .where("auto_close_hours IS NOT NULL")
          .find_each do |cat|
            cat.set_or_create_timer! user: Discourse.system_user,
                                     status_type: CategoryDefaultTimer.types[:close],
                                     duration_minutes: cat.auto_close_hours.to_i * 60,
                                     based_on_last_post: cat.auto_close_based_on_last_post
          end
      end
      dir.down do
        # remove all null rows
        execute <<-SQL
          DELETE FROM topic_timers
          WHERE execute_at IS NULL
        SQL

        change_column_null :topic_timers, :execute_at, false
      end
    end

    add_index :topic_timers, :type
  end
end
