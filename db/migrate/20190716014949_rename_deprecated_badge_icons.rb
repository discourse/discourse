# frozen_string_literal: true

class RenameDeprecatedBadgeIcons < ActiveRecord::Migration[5.2]
  def up
    execute "UPDATE badges SET icon = 'far-clock' WHERE icon = 'fa-clock-o'"
    execute "UPDATE badges SET icon = 'far-eye' WHERE icon = 'fa-eye'"
  end

  def down
    execute "UPDATE badges SET icon = 'fa-clock-o' WHERE icon = 'far-clock'"
    execute "UPDATE badges SET icon = 'fa-eye' WHERE icon = 'far-eye'"
  end
end
