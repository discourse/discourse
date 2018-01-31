class RenamePrivatePersonal < ActiveRecord::Migration[5.1]

  def setting(old, new)
    execute "UPDATE site_settings SET name='#{new}' where name='#{old}'"
  end

  def up
    setting :min_private_message_post_length, :min_personal_message_post_length
    setting :min_private_message_title_length, :min_personal_message_title_length
    setting :enable_private_messages, :enable_personal_messages
    setting :enable_private_email_messages, :enable_personal_email_messages
  end

  def down
    setting :min_private_message_post_length, :min_personal_message_post_length
    setting :min_private_message_title_length, :min_personal_message_title_length
    setting :enable_private_messages, :enable_personal_messages
    setting :enable_private_email_messages, :enable_personal_email_messages
  end
end
