class RemoveOldColumnsFromUsers < ActiveRecord::Migration
  def up
    %w{
      email_always
      mailing_list_mode
      email_digests
      email_direct
      email_private_messages
      external_links_in_new_tab
      enable_quoting
      dynamic_favicon
      disable_jump_reply
      edit_history_public
      automatically_unpin_topics
      digest_after_days
      auto_track_topics_after_msecs
      new_topic_duration_minutes
      last_redirected_to_top_at
    }.each do |column|
      User.exec_sql("ALTER TABLE users DROP column IF EXISTS #{column}")
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
