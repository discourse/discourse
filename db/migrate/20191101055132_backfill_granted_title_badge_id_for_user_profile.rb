# frozen_string_literal: true
class BackfillGrantedTitleBadgeIdForUserProfile < ActiveRecord::Migration[6.0]
  def up
    # update all the regular badge derived titles based
    # on the normal badge name
    ActiveRecord::Base.connection.execute <<-SQL
      UPDATE user_profiles
      SET granted_title_badge_id = b.id
      FROM users
      INNER JOIN badges b ON users.title = b.name
      WHERE users.title = b.name
        AND user_profiles.granted_title_badge_id IS NULL
        AND users.id = user_profiles.user_id
        AND users.title IS NOT NULL AND users.title != ''
    SQL

    # update all of the system badge derived titles where the
    # badge has had custom text set for it via TranslationOverride
    ActiveRecord::Base.connection.execute <<-SQL
      UPDATE user_profiles
      SET granted_title_badge_id = badges.id
      FROM users
      JOIN translation_overrides ON translation_overrides.value = users.title
      JOIN badges ON ('badges.' || LOWER(REPLACE(badges.name, ' ', '_')) || '.name') = translation_overrides.translation_key
      JOIN user_badges ON user_badges.user_id = users.id AND user_badges.badge_id = badges.id
      WHERE users.title = translation_overrides.value
        AND user_profiles.granted_title_badge_id IS NULL
        AND users.id = user_profiles.user_id
        AND users.title IS NOT NULL AND users.title != ''
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
