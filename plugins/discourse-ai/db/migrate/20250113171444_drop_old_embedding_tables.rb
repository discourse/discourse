# frozen_string_literal: true
class DropOldEmbeddingTables < ActiveRecord::Migration[7.2]
  def up
    # Copy rag embeddings created during deploy.
    # noop. TODO(roman): Will follow-up with a new migration to drop these tables.
  end

  def down
  end
end
