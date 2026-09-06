# frozen_string_literal: true

class AddCustomFieldsToEvent < ActiveRecord::Migration[6.0]
  def up
    add_column :discourse_post_event_events, :custom_fields, :jsonb, null: false, default: {}
  end

  def down
    remove_column :discourse_post_event_events, :custom_fields
  end
end
