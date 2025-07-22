# frozen_string_literal: true
class MatryoshkaDimensionsSupport < ActiveRecord::Migration[7.2]
  def change
    add_column :embedding_definitions, :matryoshka_dimensions, :boolean, null: false, default: false

    execute <<~SQL
      UPDATE embedding_definitions
      SET matryoshka_dimensions = TRUE
      WHERE 
        provider = 'open_ai' AND 
        provider_params IS NOT NULL AND
        (
          (provider_params->>'model_name') = 'text-embedding-3-large' OR
          (provider_params->>'model_name') = 'text-embedding-3-small'
        )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
