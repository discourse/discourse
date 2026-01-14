# frozen_string_literal: true
class AddArtifactVersions < ActiveRecord::Migration[7.0]
  def change
    create_table :ai_artifact_versions do |t|
      t.bigint :ai_artifact_id, null: false
      t.integer :version_number, null: false
      t.string :html, limit: 65_535
      t.string :css, limit: 65_535
      t.string :js, limit: 65_535
      t.jsonb :metadata
      t.string :change_description
      t.timestamps

      t.index %i[ai_artifact_id version_number], unique: true
    end
  end
end
