# frozen_string_literal: true

class AmendCssColumnsInTheme < ActiveRecord::Migration[4.2]
  def change
    rename_column :themes, :stylesheet, :desktop_scss
    rename_column :themes, :mobile_stylesheet, :mobile_scss
    rename_column :themes, :embedded_css, :embedded_scss

    add_column :themes, :common_scss, :text

    remove_column :themes, :stylesheet_baked
    remove_column :themes, :mobile_stylesheet_baked
    remove_column :themes, :embedded_css_baked
  end
end
