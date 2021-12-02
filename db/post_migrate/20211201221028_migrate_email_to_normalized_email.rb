# frozen_string_literal: true

class MigrateEmailToNormalizedEmail < ActiveRecord::Migration[6.1]

  # minimize locking on user_email table
  disable_ddl_transaction!

  def up

    min, max = DB.query_single "SELECT MIN(id), MAX(id) FROM user_emails"
    # scaling is needed to compensate for "holes" where records were deleted
    # and pathological cases where for some reason id 100_000_000 and 0 exist

    # avoid doing any work on empty dbs
    return if min.nil?

    bounds = DB.query_single <<~SQL
      SELECT t.id
      FROM (
        SELECT *, row_number() OVER(ORDER BY id ASC) AS row
        FROM user_emails
      ) t
      WHERE t.row % 100000 = 0
    SQL

    # subtle but loop does < not <=
    # includes low, excludes high
    bounds << (max + 1)

    low_id = min
    bounds.each do |high_id|

      # using execute cause MiniSQL is not logging at the moment
      # to_i is not needed, but specified so it is explicit there is no SQL injection
      execute <<~SQL
        UPDATE user_emails
        SET normalized_email = REPLACE(REGEXP_REPLACE(email,'([+@].*)',''),'.','') || REGEXP_REPLACE(email, '[^@]*', '')
        WHERE (normalized_email IS NULL OR normalized_email <> (REPLACE(REGEXP_REPLACE(email,'([+@].*)',''),'.','') || REGEXP_REPLACE(email, '[^@]*', '')))
          AND (id >= #{low_id.to_i} AND id < #{high_id.to_i})
      SQL

      low_id = high_id
    end

  end

  def down
    execute "UPDATE user_emails SET normalized_email = null"
  end
end
