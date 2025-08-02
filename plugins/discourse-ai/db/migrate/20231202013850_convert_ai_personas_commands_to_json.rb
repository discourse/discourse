# frozen_string_literal: true
class ConvertAiPersonasCommandsToJson < ActiveRecord::Migration[7.0]
  def up
    # this all may be a bit surprising, but interestingly this makes all our backend code
    # cross compatible
    # upgrading ["a", "b", "c"] to json simply works cause in both cases
    # rails will cast to a string array and all code simply expects a string array
    #
    # this change was made so we can also start storing parameters with the commands
    execute <<~SQL
      ALTER TABLE ai_personas
      ALTER COLUMN commands DROP DEFAULT
    SQL

    execute <<~SQL
      ALTER TABLE ai_personas
      ALTER COLUMN commands
      TYPE json USING array_to_json(commands)
    SQL

    execute <<~SQL
      ALTER TABLE ai_personas
      ALTER COLUMN commands
      SET DEFAULT '[]'::json
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
