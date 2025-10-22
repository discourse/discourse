# frozen_string_literal: true

class AddLastRemindedAtIndex < ActiveRecord::Migration[5.2]
  def change
    add_index :user_custom_fields,
              %i[name user_id],
              name: :idx_user_custom_fields_last_reminded_at,
              unique: true,
              where: "name = 'last_reminded_at'"
  end
end
