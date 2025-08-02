# frozen_string_literal: true
class AnonymizeNormalizedEmailColumn < ActiveRecord::Migration[7.1]
  def up
    execute <<~SQL
      UPDATE user_emails
      SET normalized_email = email
      WHERE SPLIT_PART(email, '@', 2) = 'anonymized.invalid'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
