# frozen_string_literal: true

class RenameCategoryGroupModerationSetting < ActiveRecord::Migration[6.0]
  def up
    execute "UPDATE site_settings SET name = 'enable_category_group_moderation' WHERE name = 'enable_category_group_review'"
    execute "UPDATE user_histories SET subject = 'enable_category_group_moderation' WHERE subject = 'enable_category_group_review'"
  end

  def down
    execute "UPDATE site_settings SET name = 'enable_category_group_review' WHERE name = 'enable_category_group_moderation'"
    execute "UPDATE user_histories SET subject = 'enable_category_group_review' WHERE subject = 'enable_category_group_moderation'"
  end
end
