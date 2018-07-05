class AddThemeIdToUserOption < ActiveRecord::Migration[5.2]
  def up
    add_column :user_options, :theme_ids, :integer, array: true,  null: false, default: []

    execute(
      "UPDATE user_options AS uo
       SET theme_ids = (
         SELECT array_agg(themes.id)
         FROM themes
         INNER JOIN user_options
         ON themes.key = user_options.theme_key
         WHERE user_options.user_id = uo.user_id
       ) WHERE uo.theme_key IN (SELECT key FROM themes)"
    )

    begin
      Migration::SafeMigrate.disable!
      remove_column :user_options, :theme_key
    ensure
      Migration::SafeMigrate.enable!
    end
  end

  def down
    add_column :user_options, :theme_key, :string

    execute(
      "UPDATE user_options AS uo
       SET theme_key = (
         SELECT themes.key
         FROM themes
         INNER JOIN user_options
         ON themes.id = user_options.theme_ids[1]
         WHERE user_options.user_id = uo.user_id
       ) WHERE uo.theme_ids[1] IN (SELECT id FROM themes)"
    )

    begin
      Migration::SafeMigrate.disable!
      remove_column :user_options, :theme_ids
    ensure
      Migration::SafeMigrate.enable!
    end
  end
end
