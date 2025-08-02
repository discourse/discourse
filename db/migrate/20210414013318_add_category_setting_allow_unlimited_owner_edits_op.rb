# frozen_string_literal: true

class AddCategorySettingAllowUnlimitedOwnerEditsOp < ActiveRecord::Migration[6.0]
  def change
    add_column :categories,
               :allow_unlimited_owner_edits_on_first_post,
               :boolean,
               default: false,
               null: false
  end
end
