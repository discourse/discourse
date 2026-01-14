# frozen_string_literal: true

class AddProviderToCompletionPrompts < ActiveRecord::Migration[7.0]
  def up
    remove_index :completion_prompts, name: "index_completion_prompts_on_name"
    add_column :completion_prompts, :provider, :text
    add_index :completion_prompts, %i[name], unique: false

    # set provider for existing prompts
    DB.exec <<~SQL
      UPDATE completion_prompts
      SET provider = 'openai'
      WHERE provider IS NULL;
    SQL
  end

  def down
    remove_column :completion_prompts, :provider
    remove_index :completion_prompts, name: "index_completion_prompts_on_name"
    add_index :completion_prompts, %i[name], unique: true
  end
end
