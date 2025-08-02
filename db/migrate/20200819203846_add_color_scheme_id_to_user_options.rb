# frozen_string_literal: true

class AddColorSchemeIdToUserOptions < ActiveRecord::Migration[6.0]
  def change
    add_column :user_options, :color_scheme_id, :integer
  end
end
