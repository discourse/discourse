class RenameCategoryGroupModerationSetting < ActiveRecord::Migration[6.0]
  def change
	  execute "UPDATE site_settings SET name = 'enable_category_group_moderation' WHERE name = 'enable_category_group_review'"
	  execute "UPDATE user_histories SET subject = 'enable_category_group_moderation' WHERE subject = 'enable_category_group_review'"
  end
end
