# frozen_string_literal: true

class RenameExperimentalMarkdownEndpoints < ActiveRecord::Migration[8.0]
  def up
    execute(<<~SQL)
      UPDATE site_settings
      SET name = 'enable_markdown_endpoints'
      WHERE name = 'experimental_markdown_endpoints'
    SQL
  end

  def down
    execute(<<~SQL)
      UPDATE site_settings
      SET name = 'experimental_markdown_endpoints'
      WHERE name = 'enable_markdown_endpoints'
    SQL
  end
end
