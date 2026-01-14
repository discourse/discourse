# frozen_string_literal: true

class CorrectUserNotesCount < ActiveRecord::Migration[5.2]
  # This corrects an error in the previous migration (now fixed)

  def up
    execute <<~SQL
      INSERT INTO user_custom_fields (
        user_id,
        name,
        value,
        created_at,
        updated_at
      ) SELECT
          REPLACE(key, 'notes:', '')::int,
          'user_notes_count',
          json_array_length(value::json),
          now(),
          now()
          FROM plugin_store_rows
          WHERE plugin_name = 'user_notes'
          AND key LIKE 'notes:%'
      ON CONFLICT (name, user_id) WHERE name::text = 'user_notes_count'::text
      DO NOTHING
    SQL
  end

  def down
    # Nothing to do
  end
end
