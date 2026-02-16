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
end
