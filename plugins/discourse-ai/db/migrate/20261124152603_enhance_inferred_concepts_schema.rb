# frozen_string_literal: true
class EnhanceInferredConceptsSchema < ActiveRecord::Migration[8.1]
  def change
    add_column :inferred_concepts, :description, :text, null: false, default: ""
    add_column :inferred_concepts, :slug, :string, null: false, default: ""
    add_column :inferred_concepts, :status, :integer, null: false, default: 1
    add_column :inferred_concepts, :aliases, :text, array: true, null: false, default: []
    add_column :inferred_concepts, :parent_id, :bigint

    add_index :inferred_concepts, :parent_id, where: "parent_id IS NOT NULL"
    add_index :inferred_concepts, :status
    add_index :inferred_concepts, :slug, unique: true, where: "slug <> ''"
    add_index :inferred_concepts, "lower(name)", name: "index_inferred_concepts_on_lower_name"

    add_column :inferred_concept_topics, :relevance, :float, null: false, default: 1.0
    add_column :inferred_concept_topics, :primary, :boolean, null: false, default: false
    add_column :inferred_concept_topics, :digest, :string, null: false, default: ""

    add_column :inferred_concept_posts, :relevance, :float, null: false, default: 1.0
    add_column :inferred_concept_posts, :primary, :boolean, null: false, default: false
    add_column :inferred_concept_posts, :digest, :string, null: false, default: ""
  end
end
