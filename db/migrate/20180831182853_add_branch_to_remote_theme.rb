# frozen_string_literal: true

class AddBranchToRemoteTheme < ActiveRecord::Migration[5.2]
  def change
    add_column :remote_themes, :branch, :string
  end
end
