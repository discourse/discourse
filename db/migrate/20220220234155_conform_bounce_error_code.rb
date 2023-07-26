# frozen_string_literal: true
#
class ConformBounceErrorCode < ActiveRecord::Migration[6.1]
  def up
    DB.exec(<<~SQL, regexp: '\d\.\d\.\d+|\d{3}')
      UPDATE email_logs
      SET bounce_error_code = (
        SELECT array_to_string(
          regexp_matches(bounce_error_code, :regexp),
          ''
        )
      ) WHERE bounce_error_code IS NOT NULL;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
