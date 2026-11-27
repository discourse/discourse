# frozen_string_literal: true
class IndexEventRegistrationsForReportingAndCleanup < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    down
    add_index :discourse_event_registrations, :user_id, algorithm: :concurrently
    add_index :discourse_event_registrations,
              :event_id,
              name: "idx_unreported_event_registrations",
              where: "report_post_id IS NULL",
              algorithm: :concurrently
  end

  def down
    remove_index :discourse_event_registrations, :user_id, if_exists: true, algorithm: :concurrently
    remove_index :discourse_event_registrations,
                 name: "idx_unreported_event_registrations",
                 if_exists: true,
                 algorithm: :concurrently
  end
end
