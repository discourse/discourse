# frozen_string_literal: true

class CreateRedeliveringWebhookEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :redelivering_webhook_events do |t|
      t.belongs_to :web_hook_event, null: false, index: true
      t.boolean :processing, default: false, null: false

      t.timestamps
    end
  end
end
