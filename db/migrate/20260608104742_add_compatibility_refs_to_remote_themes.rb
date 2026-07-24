# frozen_string_literal: true

class AddCompatibilityRefsToRemoteThemes < ActiveRecord::Migration[8.0]
  def change
    add_column :remote_themes, :local_compat_ref, :string
    add_column :remote_themes, :remote_compat_ref, :string
  end
end
