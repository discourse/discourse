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

    def user_option
      UserOption.new
    end
  end
end

# == Schema Information
#
# Table name: users
#
#  id                        :integer          not null, primary key
#  active                    :boolean          default(FALSE), not null
#  admin                     :boolean          default(FALSE), not null
#  approved                  :boolean          default(FALSE), not null
#  approved_at               :datetime
#  date_of_birth             :date
#  first_seen_at             :datetime
#  flag_level                :integer          default(0), not null
#  group_locked_trust_level  :integer
#  ip_address                :inet
#  last_emailed_at           :datetime
#  last_posted_at            :datetime
#  last_seen_at              :datetime
#  locale                    :string(10)
#  manual_locked_trust_level :integer
#  moderator                 :boolean          default(FALSE)
#  name                      :string
#  previous_visit_at         :datetime
#  registration_ip_address   :inet
#  required_fields_version   :integer
#  secure_identifier         :string
#  silenced_till             :datetime
#  staged                    :boolean          default(FALSE), not null
#  suspended_at              :datetime
#  suspended_till            :datetime
#  title                     :string
#  trust_level               :integer          not null
#  username                  :string(60)       not null
#  username_lower            :string(60)       not null
#  views                     :integer          default(0), not null
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  approved_by_id            :integer
#  flair_group_id            :integer
#  last_seen_reviewable_id   :integer
#  primary_group_id          :integer
#  seen_notification_id      :bigint           default(0), not null
#  uploaded_avatar_id        :integer
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
