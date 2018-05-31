class RenamePrivatePersonal < ActiveRecord::Migration[5.1]

  def setting(old, new)
    execute "UPDATE site_settings SET name='#{new}' where name='#{old}'"
  end

  def up
    setting :min_private_message_post_length, :min_personal_message_post_length
    setting :min_private_message_title_length, :min_personal_message_title_length
    setting :enable_private_messages, :enable_personal_messages
    setting :enable_private_email_messages, :enable_personal_email_messages
    setting :private_email_time_window_seconds, :personal_email_time_window_seconds
    setting :max_private_messages_per_day, :max_personal_messages_per_day
    setting :default_email_private_messages, :default_email_personal_messages
  end

  def down
    setting :min_personal_message_post_length, :min_private_message_post_length
    setting :min_personal_message_title_length, :min_private_message_title_length
    setting :enable_personal_messages, :enable_private_messages
    setting :enable_personal_email_messages, :enable_private_email_messages
    setting :personal_email_time_window_seconds, :private_email_time_window_seconds
    setting :max_personal_messages_per_day, :max_private_messages_per_day
    setting :default_email_personal_messages, :default_email_private_messages
  end
end
