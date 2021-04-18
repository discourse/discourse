# frozen_string_literal: true

class AddCssPropertiesToGroups < ActiveRecord::Migration[6.0]
  def change
    add_column :groups, :css_properties, :text
  end
end
