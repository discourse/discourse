# frozen_string_literal: true

class FixDiscourseRewindDisabledNullConstraint < ActiveRecord::Migration[7.2]
  def up
    # The previous migration (20260105171115) changed the default to nil and marked
    # the column as readonly, but forgot to remove the NOT NULL constraint.
    # This caused failures when inserting new rows (e.g., during seeding or new user signup).
    # This migration fixes databases that already ran the broken migration.
    return unless column_exists?(:user_options, :discourse_rewind_disabled)

    change_column_null :user_options, :discourse_rewind_disabled, true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
