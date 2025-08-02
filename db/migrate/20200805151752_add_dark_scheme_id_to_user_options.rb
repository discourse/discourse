# frozen_string_literal: true

class AddDarkSchemeIdToUserOptions < ActiveRecord::Migration[6.0]
  def change
    add_column :user_options, :dark_scheme_id, :integer
  end
end
