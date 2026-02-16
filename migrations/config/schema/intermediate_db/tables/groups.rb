# frozen_string_literal: true

Migrations::Database::Schema.table :groups do
  include :allow_membership_requests,
          :allow_unknown_sender_topic_replies,
          :automatic_membership_email_domains,
          :bio_raw,
          :created_at,
          :default_notification_level,
          :flair_bg_color,
          :flair_color,
          :flair_icon,
          :flair_upload_id,
          :full_name,
          :grant_trust_level,
          :id,
          :members_visibility_level,
          :membership_request_template,
          :mentionable_level,
          :messageable_level,
          :name,
          :primary_group,
          :public_admission,
          :public_exit,
          :publish_read_state,
          :title,
          :visibility_level

  add_column :existing_id, :numeric

  ignore :automatic,
         :bio_cooked,
         :user_count,
         reason: "These fields are either calculated or not relevant for the import process"

  ignore :email_from_alias,
         :email_password,
         :email_username,
         :has_messages,
         :incoming_email,
         reason: "TODO: Figure out if we need to import these settings"

  ignore :smtp_enabled,
         :smtp_port,
         :smtp_server,
         :smtp_ssl_mode,
         :smtp_updated_at,
         :smtp_updated_by_id,
         reason: "TODO: Add support for importing SMTP settings for groups"

  ignore :imap_enabled,
         :imap_last_error,
         :imap_last_uid,
         :imap_mailbox_name,
         :imap_new_emails,
         :imap_old_emails,
         :imap_port,
         :imap_server,
         :imap_ssl,
         :imap_uid_validity,
         :imap_updated_at,
         :imap_updated_by_id,
         reason: "IMAP has been deprecated in Discourse"
end
