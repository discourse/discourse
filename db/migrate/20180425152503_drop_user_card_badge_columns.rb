class DropUserCardBadgeColumns < ActiveRecord::Migration[5.1]
  def up
    # User card images have been moved to a plugin which uses the
    # user's custom fields instead of the card_image_badge_id column.
    execute "INSERT INTO user_custom_fields (user_id, name, value, created_at, updated_at)
      SELECT user_id, 'card_image_badge_id', card_image_badge_id, now(), now()
        FROM user_profiles
       WHERE card_image_badge_id IS NOT NULL
         AND user_id NOT IN (
            SELECT user_id
              FROM user_custom_fields
             WHERE name = 'card_image_badge_id'
         )"

    # delayed drop of the user_profiles.card_image_badge_id column
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
