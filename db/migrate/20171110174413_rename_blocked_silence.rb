class RenameBlockedSilence < ActiveRecord::Migration[5.1]

  def setting(old, new)
    execute "UPDATE site_settings SET name='#{new}' where name='#{old}'"
  end

  def up
    add_column :users, :silenced, :boolean, default: false, null: false
    execute "UPDATE users set silenced = blocked"

    setting :notify_mods_when_user_blocked, :notify_mods_when_user_silenced
    setting :auto_block_fast_typers_on_first_post, :auto_silence_fast_typers_on_first_post
    setting :auto_block_fast_typers_max_trust_level, :auto_silence_fast_typers_max_trust_level
    setting :auto_block_first_post_regex, :auto_silence_first_post_regex
    setting :num_spam_flags_to_block_new_user, :num_spam_flags_to_silence_new_user
    setting :num_users_to_block_new_user, :num_users_to_silence_new_user
    setting :num_tl3_flags_to_block_new_user, :num_tl3_flags_to_silence_new_user
    setting :num_tl3_users_to_block_new_user, :num_tl3_users_to_silence_new_user
  end

  def down
    remove_column :users, :silenced
    setting :notify_mods_when_user_silenced, :notify_mods_when_user_blocked
    setting :auto_silence_fast_typers_on_first_post, :auto_block_fast_typers_on_first_post
    setting :auto_silence_fast_typers_max_trust_level, :auto_block_fast_typers_max_trust_level
    setting :auto_silence_first_post_regex, :auto_block_first_post_regex
    setting :num_spam_flags_to_silence_new_user, :num_spam_flags_to_block_new_user
    setting :num_users_to_silence_new_user, :num_users_to_block_new_user
    setting :num_tl3_flags_to_silence_new_user, :num_tl3_flags_to_block_new_user
    setting :num_tl3_users_to_silence_new_user, :num_tl3_users_to_block_new_user
  end
end
