# frozen_string_literal: true

class RemoveDisplayInvitees < ActiveRecord::Migration[6.0]
  def up
    remove_column :discourse_post_event_events, :display_invitees
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
