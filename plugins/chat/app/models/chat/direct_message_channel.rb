# frozen_string_literal: true

module Chat
  class DirectMessageChannel < Channel
    alias_method :direct_message, :chatable

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
      slug.blank?
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
#  allow_channel_wide_mentions :boolean          default(TRUE), not null
#  auto_join_users             :boolean          default(FALSE), not null
#  chatable_type               :string           not null
#  delete_after_seconds        :integer
#  deleted_at                  :datetime
#  description                 :text
#  emoji                       :string
#  messages_count              :integer          default(0), not null
#  name                        :string
#  slug                        :string
#  status                      :integer          default("open"), not null
#  threading_enabled           :boolean          default(FALSE), not null
#  type                        :string
#  user_count                  :integer          default(0), not null
#  user_count_stale            :boolean          default(FALSE), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  chatable_id                 :bigint           not null
#  deleted_by_id               :integer
#  featured_in_category_id     :integer
#  last_message_id             :bigint
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
