# frozen_string_literal: true

class FixReviewableUsers < ActiveRecord::Migration[5.2]
  def up
    execute(<<~SQL)
      UPDATE reviewables
      SET payload = json_build_object(
        'username', u.username,
        'name', u.name,
        'email', ue.email
      )::jsonb
      FROM reviewables AS r
      LEFT OUTER JOIN users AS u ON u.id = r.target_id
      LEFT OUTER JOIN user_emails AS ue ON ue.user_id = u.id AND ue.primary
      WHERE r.id = reviewables.id
        AND r.type = 'ReviewableUser'
    SQL
  end

  def down
  end
end
