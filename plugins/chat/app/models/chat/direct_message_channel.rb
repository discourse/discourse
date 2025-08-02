# frozen_string_literal: true

module Chat
  class DirectMessageChannel < Channel
    alias_method :direct_message, :chatable

    before_validation(on: :create) { self.threading_enabled = true }

    def direct_message_channel?
      true
    end

    def allowed_user_ids
      direct_message.user_ids
    end

    def read_restricted?
      true
    end

    def title(user)
      direct_message.chat_channel_title_for_user(self, user)
    end

    def generate_auto_slug
      self.slug.blank?
    end

    # Group DMs are DMs with > 2 users
    def direct_message_group?
      direct_message.group?
    end

    def leave(user)
      return super if !direct_message_group?
      transaction do
        membership_for(user)&.destroy!
        direct_message.users.delete(user)
      end
    end
  end
end

# == Schema Information
#
# Table name: chat_channels
#
#  id                          :bigint           not null, primary key
#  chatable_id                 :bigint           not null
#  deleted_at                  :datetime
#  deleted_by_id               :integer
#  featured_in_category_id     :integer
#  delete_after_seconds        :integer
#  chatable_type               :string           not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  name                        :string
#  description                 :text
#  status                      :integer          default("open"), not null
#  user_count                  :integer          default(0), not null
#  auto_join_users             :boolean          default(FALSE), not null
#  user_count_stale            :boolean          default(FALSE), not null
#  slug                        :string
#  type                        :string
#  allow_channel_wide_mentions :boolean          default(TRUE), not null
#  messages_count              :integer          default(0), not null
#  threading_enabled           :boolean          default(FALSE), not null
#  last_message_id             :bigint
#  icon_upload_id              :integer
#
# Indexes
#
#  index_chat_channels_on_chatable_id                    (chatable_id)
#  index_chat_channels_on_chatable_id_and_chatable_type  (chatable_id,chatable_type)
#  index_chat_channels_on_last_message_id                (last_message_id)
#  index_chat_channels_on_messages_count                 (messages_count)
#  index_chat_channels_on_slug                           (slug) UNIQUE WHERE ((slug)::text <> ''::text)
#  index_chat_channels_on_status                         (status)
#
