# frozen_string_literal: true

class ChangeThemeFieldCompilerVersion < ActiveRecord::Migration[5.2]
  def change
    change_column(:theme_fields, :compiler_version, :string, limit: 50)
  end
end
