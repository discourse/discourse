# frozen_string_literal: true

class RenameAllowAnonymousPostingToAllowAnonymousMode < ActiveRecord::Migration[7.2]
  def up
    execute(<<~SQL)
      UPDATE site_settings
      SET name = 'allow_anonymous_mode'
      WHERE name = 'allow_anonymous_posting'
    SQL
  end

  def down
    execute(<<~SQL)
      UPDATE site_settings
      SET name = 'allow_anonymous_posting'
      WHERE name = 'allow_anonymous_mode'
    SQL
  end
end
