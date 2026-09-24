# frozen_string_literal: true

class AddHiddenComposerToolbarButtonsToUserOptions < ActiveRecord::Migration[8.0]
  def change
    add_column :user_options,
               :hidden_composer_toolbar_buttons,
               :string,
               array: true,
               default: [],
               null: false
  end
end
