# frozen_string_literal: true

class AddRemindsAssignFrequencyIndex < ActiveRecord::Migration[5.2]
  def change
    add_index :user_custom_fields,
              %i[name user_id],
              name: :idx_user_custom_fields_remind_assigns_frequency,
              unique: true,
              where: "name = 'remind_assigns_frequency'"
  end
end
