# frozen_string_literal: true

class CorrectlyMoveAssignmentsFromCustomFieldsToATable < ActiveRecord::Migration[6.1]
  def up
    # An old version of 20210709101534 incorrectly imported `assignments` with
    # the topic_id and assigned_to_id columns flipped. This query deletes those invalid records.

    if column_exists?(:assignments, :target_id)
      execute <<~SQL
        INSERT INTO assignments (assigned_to_id, assigned_by_user_id, topic_id, created_at, updated_at, assigned_to_type, target_id, target_type)
        SELECT
          assigned_to.value::integer,
          assigned_by.value::integer,
          assigned_by.topic_id,
          assigned_by.created_at,
          assigned_by.updated_at,
          'User',
          assigned_by.topic_id,
          'Topic'
        FROM topic_custom_fields assigned_by
        INNER JOIN topic_custom_fields assigned_to ON assigned_to.topic_id = assigned_by.topic_id
        WHERE assigned_by.name = 'assigned_by_id'
          AND assigned_to.name = 'assigned_to_id'
        ORDER BY assigned_by.created_at DESC
        ON CONFLICT DO NOTHING
      SQL
    elsif column_exists?(:assignments, :assigned_to_type)
      execute <<~SQL
        INSERT INTO assignments (assigned_to_id, assigned_by_user_id, topic_id, created_at, updated_at, assigned_to_type)
        SELECT
          assigned_to.value::integer,
          assigned_by.value::integer,
          assigned_by.topic_id,
          assigned_by.created_at,
          assigned_by.updated_at,
          'User',
        FROM topic_custom_fields assigned_by
        INNER JOIN topic_custom_fields assigned_to ON assigned_to.topic_id = assigned_by.topic_id
        WHERE assigned_by.name = 'assigned_by_id'
          AND assigned_to.name = 'assigned_to_id'
        ORDER BY assigned_by.created_at DESC
        ON CONFLICT DO NOTHING
      SQL
    else
      execute <<~SQL
        INSERT INTO assignments (assigned_to_id, assigned_by_user_id, topic_id, created_at, updated_at)
        SELECT
          assigned_to.value::integer,
          assigned_by.value::integer,
          assigned_by.topic_id,
          assigned_by.created_at,
          assigned_by.updated_at
        FROM topic_custom_fields assigned_by
        INNER JOIN topic_custom_fields assigned_to ON assigned_to.topic_id = assigned_by.topic_id
        WHERE assigned_by.name = 'assigned_by_id'
          AND assigned_to.name = 'assigned_to_id'
        ORDER BY assigned_by.created_at DESC
        ON CONFLICT DO NOTHING
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
