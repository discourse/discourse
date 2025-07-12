# frozen_string_literal: true

module Chat
  class CategoryChannel < Channel
    alias_method :category, :chatable

    delegate :read_restricted?, to: :category
    delegate :url, to: :chatable, prefix: true

    %i[category_channel? public_channel? chatable_has_custom_fields?].each do |name|
      define_method(name) { true }
    end

    STAFF_GROUP_IDS = Group::AUTO_GROUPS.values_at(:admins, :moderators, :staff)

    def allowed_group_ids
      return if !read_restricted?

      STAFF_GROUP_IDS | category.secure_group_ids
    end

    def title(_ = nil)
      name.presence || category.name
    end

    def generate_auto_slug
      return if self.slug.present?
      self.slug = Slug.for(self.title.strip, "")
      self.slug = "" if duplicate_slug?
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
