# frozen_string_literal: true
class ConfigurableEmbeddingsPrefixes < ActiveRecord::Migration[7.2]
  def up
    add_column :embedding_definitions, :embed_prompt, :string, null: false, default: ""
    add_column :embedding_definitions, :search_prompt, :string, null: false, default: ""

    # 4 is bge-large-en. Default model and the only one using this so far.
    execute <<~SQL
      UPDATE embedding_definitions
      SET search_prompt='Represent this sentence for searching relevant passages:'
      WHERE id = 4
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
