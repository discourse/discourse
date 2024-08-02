# frozen_string_literal: true
class UpdateInvalidAllowedIframeValues < ActiveRecord::Migration[7.1]
  def up
    prev_value =
      DB.query_single("SELECT value FROM site_settings WHERE name = 'allowed_iframes'").first

    return if prev_value.blank?

    # Url starts with http:// or https:// and has at least one more additional '/'
    regex = %r{\Ahttps?://([^/]*/)+[^/]*\z}x

    new_value =
      prev_value
        .split("|")
        .map do |substring|
          if substring.match?(regex)
            substring
          else
            "#{substring}/"
          end
        end
        .uniq
        .join("|")

    return if new_value == prev_value

    DB.exec(<<~SQL, new_value:)
      UPDATE site_settings
      SET value = :new_value
      WHERE name = 'allowed_iframes'
    SQL

    DB.exec(<<~SQL, prev_value:, new_value:)
      INSERT INTO user_histories (action, subject, previous_value, new_value, admin_only, updated_at, created_at, acting_user_id)
      VALUES (3, 'allowed_iframes', :prev_value, :new_value, true, NOW(), NOW(), -1)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
