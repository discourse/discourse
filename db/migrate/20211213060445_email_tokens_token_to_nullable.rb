# frozen_string_literal: true

class EmailTokensTokenToNullable < ActiveRecord::Migration[6.1]
  def up
    # ensure column is nullable in case any inserts happen
    # prior to post migrations
    #
    # using this somewhat verbose pattern to avoid impacting people who
    # drifted on main
    begin
      Migration::SafeMigrate.disable!
      if DB.query_single(<<~SQL).length > 0
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE table_schema='public'
        AND table_name = 'email_tokens'
        AND column_name = 'token'
      SQL
        execute <<~SQL
          ALTER TABLE email_tokens ALTER COLUMN token DROP NOT NULL
        SQL
      end
    ensure
      Migration::SafeMigrate.enable!
    end
  end

  def down
    # do nothing, does not matter
  end
end
