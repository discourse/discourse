# frozen_string_literal: true

class CreateWebHookEventTypes < ActiveRecord::Migration[4.2]
  def change
    create_table :web_hook_event_types do |t|
      t.string :name, null: false
    end
  end
end
