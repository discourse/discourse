# frozen_string_literal: true

class AddsAutomationIdsIndexToPostCustomFields < ActiveRecord::Migration[5.2]
  def change
    add_index :post_custom_fields,
              %i[post_id value],
              unique: true,
              where: "name = 'discourse_automation_ids'",
              name: :idx_post_custom_fields_discourse_automation_unique_id_partial
  end
end
