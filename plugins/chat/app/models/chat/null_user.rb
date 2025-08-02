# frozen_string_literal: true

module Chat
  class NullUser < User
    def username
      I18n.t("chat.deleted_chat_username")
    end

    def avatar_template
      "/plugins/chat/images/deleted-chat-user-avatar.png"
    end

    def bot?
      false
    end
  end
end

# == Schema Information
#
# Table name: users
#
#  id                        :integer          not null, primary key
#  username                  :string(60)       not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  name                      :string
#  last_posted_at            :datetime
#  active                    :boolean          default(FALSE), not null
#  username_lower            :string(60)       not null
#  last_seen_at              :datetime
#  admin                     :boolean          default(FALSE), not null
#  last_emailed_at           :datetime
#  trust_level               :integer          not null
#  approved                  :boolean          default(FALSE), not null
#  approved_by_id            :integer
#  approved_at               :datetime
#  previous_visit_at         :datetime
#  suspended_at              :datetime
#  suspended_till            :datetime
#  date_of_birth             :date
#  views                     :integer          default(0), not null
#  flag_level                :integer          default(0), not null
#  ip_address                :inet
#  moderator                 :boolean          default(FALSE)
#  title                     :string
#  uploaded_avatar_id        :integer
#  locale                    :string(10)
#  primary_group_id          :integer
#  registration_ip_address   :inet
#  staged                    :boolean          default(FALSE), not null
#  first_seen_at             :datetime
#  silenced_till             :datetime
#  group_locked_trust_level  :integer
#  manual_locked_trust_level :integer
#  secure_identifier         :string
#  flair_group_id            :integer
#  last_seen_reviewable_id   :integer
#  required_fields_version   :integer
#  seen_notification_id      :bigint           default(0), not null
#
# Indexes
#
#  idx_users_admin                    (id) WHERE admin
#  idx_users_ip_address               (ip_address)
#  idx_users_moderator                (id) WHERE moderator
#  index_users_on_last_posted_at      (last_posted_at)
#  index_users_on_last_seen_at        (last_seen_at)
#  index_users_on_secure_identifier   (secure_identifier) UNIQUE
#  index_users_on_uploaded_avatar_id  (uploaded_avatar_id)
#  index_users_on_username            (username) UNIQUE
#  index_users_on_username_lower      (username_lower) UNIQUE
#
