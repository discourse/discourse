class RenameModeratorsCreateCategoriesSetting < ActiveRecord::Migration[6.0]
  def up
    # TODO - do we need to rename old UserHistory log entries too?
    # TODO - should the name be "moderators_manage_categories_and_groups"?
    execute "UPDATE site_settings SET name = 'moderators_create_categories_and_groups' WHERE name = 'moderators_create_categories'"
  end

  def down
    execute "UPDATE site_settings SET name = 'moderators_create_categories' WHERE name = 'moderators_create_categories_and_groups'"
  end
end
