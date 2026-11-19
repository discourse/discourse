# frozen_string_literal: true

class AddTopicCreationPromptToCategories < ActiveRecord::Migration[8.0]
  def change
    add_column :categories, :topic_creation_prompt, :text
    add_column :categories, :topic_creation_prompt_max_trust_level, :integer, limit: 2
  end
end
