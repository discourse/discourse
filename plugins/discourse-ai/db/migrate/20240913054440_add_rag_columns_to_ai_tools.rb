# frozen_string_literal: true

class AddRagColumnsToAiTools < ActiveRecord::Migration[7.1]
  def change
    add_column :ai_tools, :rag_chunk_tokens, :integer, null: false, default: 374
    add_column :ai_tools, :rag_chunk_overlap_tokens, :integer, null: false, default: 10
  end
end
