# frozen_string_literal: true

class SwitchToGenericCompletionPrompts < ActiveRecord::Migration[7.0]
  def change
    remove_column :completion_prompts, :provider, :text

    DB.exec("DELETE FROM completion_prompts WHERE (id < 0 AND id > -300)")
  end
end
