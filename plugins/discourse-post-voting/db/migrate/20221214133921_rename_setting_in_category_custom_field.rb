# frozen_string_literal: true

class RenameSettingInCategoryCustomField < ActiveRecord::Migration[6.1]
  def up
    DB.exec(<<~SQL)
      UPDATE category_custom_fields
      SET name = 'create_as_post_voting_default'
      WHERE name = 'create_as_qa_default'
    SQL
  end

  def down
    DB.exec(<<~SQL)
      UPDATE category_custom_fields
      SET name = 'create_as_qa_default'
      WHERE name = 'create_as_post_voting_default'
    SQL
  end
end
