# frozen_string_literal: true

class ChangeActionCodeHrefToActionCodePath < ActiveRecord::Migration[6.1]
  def up
    DB.exec(<<~SQL)
      UPDATE post_custom_fields
      SET name = 'action_code_path'
      WHERE name = 'action_code_href'
    SQL
  end

  def down
    DB.exec(<<~SQL)
      UPDATE post_custom_fields
      SET name = 'action_code_href'
      WHERE name = 'action_code_path'
    SQL
  end
end
