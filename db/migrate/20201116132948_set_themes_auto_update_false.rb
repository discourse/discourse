# frozen_string_literal: true

class SetThemesAutoUpdateFalse < ActiveRecord::Migration[6.0]
  def up
    execute "UPDATE themes SET auto_update = false"
  end

  def down
    execute "UPDATE themes SET auto_update = true"
  end
end
