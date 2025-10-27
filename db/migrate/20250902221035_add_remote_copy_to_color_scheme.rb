# frozen_string_literal: true

class AddRemoteCopyToColorScheme < ActiveRecord::Migration[8.0]
  def change
    add_column :color_schemes, :remote_copy, :boolean, default: false, null: false
  end
end
