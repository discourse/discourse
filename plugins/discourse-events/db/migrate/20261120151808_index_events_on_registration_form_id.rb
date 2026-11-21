# frozen_string_literal: true
class IndexEventsOnRegistrationFormId < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    down
    add_index :discourse_post_event_events,
              :registration_form_id,
              where: "registration_form_id IS NOT NULL AND deleted_at IS NULL",
              algorithm: :concurrently
  end

  def down
    remove_index :discourse_post_event_events,
                 :registration_form_id,
                 algorithm: :concurrently,
                 if_exists: true
  end
end
