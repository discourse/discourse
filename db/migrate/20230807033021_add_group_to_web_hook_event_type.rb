# frozen_string_literal: true

class AddGroupToWebHookEventType < ActiveRecord::Migration[7.0]
  def change
    add_column :web_hook_event_types, :group, :integer
  end
end
