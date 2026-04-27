# frozen_string_literal: true

class AddIndexToAiArtifactsPostId < ActiveRecord::Migration[8.0]
  def change
    add_index :ai_artifacts, :post_id
  end
end
