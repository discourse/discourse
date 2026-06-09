# frozen_string_literal: true

class MakeAiArtifactPostIdNullable < ActiveRecord::Migration[8.0]
  def change
    change_column_null :ai_artifacts, :post_id, true
  end
end
