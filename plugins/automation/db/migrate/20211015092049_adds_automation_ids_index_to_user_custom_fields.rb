# frozen_string_literal: true

class AddsAutomationIdsIndexToUserCustomFields < ActiveRecord::Migration[5.2]
  def change
    add_index :user_custom_fields,
              %i[user_id value],
              unique: true,
              where: "name = 'discourse_automation_ids'",
              name: :idx_user_custom_fields_discourse_automation_unique_id_partial
  end
end
