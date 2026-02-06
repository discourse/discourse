# frozen_string_literal: true

class UserCustomField < ActiveRecord::Base
  include CustomField

  belongs_to :user

  scope :searchable,
        -> do
          joins(
            "INNER JOIN user_fields ON user_fields.id = REPLACE(user_custom_fields.name, 'user_field_', '')::INTEGER",
          ).where("user_fields.searchable = TRUE").where(
            "user_custom_fields.name ~ ?",
            '^user_field_\\d+$',
          )
        end
end

# == Schema Information
#
# Table name: user_custom_fields
#
#  id         :integer          not null, primary key
#  name       :string(256)      not null
#  value      :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :integer          not null
#
# Indexes
#
#  global_community_index_on_user_fields_custom_fields           (name,value) WHERE ((name)::text ~~ 'user_field_%'::text)
#  idx_user_custom_fields_allow_people_to_follow_me              (name,user_id) UNIQUE WHERE ((name)::text = 'allow_people_to_follow_me'::text)
#  idx_user_custom_fields_global_filter_preference               (name,user_id) UNIQUE WHERE ((name)::text = 'global_filter_preference'::text)
#  idx_user_custom_fields_last_reminded_at                       (name,user_id) UNIQUE WHERE ((name)::text = 'last_reminded_at'::text)
#  idx_user_custom_fields_notify_followed_user_when_followed     (name,user_id) UNIQUE WHERE ((name)::text = 'notify_followed_user_when_followed'::text)
#  idx_user_custom_fields_notify_me_when_followed                (name,user_id) UNIQUE WHERE ((name)::text = 'notify_me_when_followed'::text)
#  idx_user_custom_fields_notify_me_when_followed_creates_topic  (name,user_id) UNIQUE WHERE ((name)::text = 'notify_me_when_followed_creates_topic'::text)
#  idx_user_custom_fields_notify_me_when_followed_replies        (name,user_id) UNIQUE WHERE ((name)::text = 'notify_me_when_followed_replies'::text)
#  idx_user_custom_fields_on_holiday                             (name,user_id) UNIQUE WHERE ((name)::text = 'on_holiday'::text)
#  idx_user_custom_fields_remind_assigns_frequency               (name,user_id) UNIQUE WHERE ((name)::text = 'remind_assigns_frequency'::text)
#  idx_user_custom_fields_user_notes_count                       (name,user_id) UNIQUE WHERE ((name)::text = 'user_notes_count'::text)
#  index_user_custom_fields_on_user_id_and_name                  (user_id,name)
#  index_user_custom_fields_on_value                             (value) UNIQUE WHERE ((name)::text = 'ai-stream-conversation-unique-id'::text)
#
