# frozen_string_literal: true

class MigrateEmailToNormalizedEmail < ActiveRecord::Migration[6.1]

  # minimize locking on user_email table
  disable_ddl_transaction!

  def up

    min, max, total = DB.query_single "SELECT MIN(id), MAX(id), COUNT(*) FROM user_emails"
    # scaling is needed to compensate for "holes" where records were deleted
    # and pathological cases where for some reason id 100_000_000 and 0 exist

    # avoid doing any work on empty dbs
    return if min.nil?

    scaling =
      if min == max
        1
      else
        total.to_f / (max - min).to_f
      end

    batch_size = 100_000

    enum = Enumerator.new do |yielder|
      low = min
      loop do
        high = (low + (batch_size / scaling)).to_i
        yielder << [low, high]
        low = high
      end
    end

    loop do
      low_id, high_id = enum.next

      break if low_id > max

      # using execute cause MiniSQL is not logging at the moment
      # to_i is not needed, but specified so it is explicit there is no SQL injection
      execute <<~SQL
        UPDATE user_emails
        SET normalized_email = REPLACE(REGEXP_REPLACE(email,'([+@].*)',''),'.','') || REGEXP_REPLACE(email, '[^@]*', '')
        WHERE (normalized_email IS NULL OR normalized_email <> (REPLACE(REGEXP_REPLACE(email,'([+@].*)',''),'.','') || REGEXP_REPLACE(email, '[^@]*', '')))
          AND (id >= #{low_id.to_i} AND id < #{high_id.to_i})
      SQL
    end
  end

  def down
    execute "UPDATE user_emails SET normalized_email = null"
  end
end
