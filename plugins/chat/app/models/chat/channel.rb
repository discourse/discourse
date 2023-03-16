# frozen_string_literal: true

module Chat
  class Channel < ActiveRecord::Base
    include Trashable

    self.table_name = "chat_channels"

    belongs_to :chatable, polymorphic: true

    def self.find_sti_class(type_name)
      return Chat::CategoryChannel if type_name == "CategoryChannel"
      return Chat::DirectMessageChannel if type_name == "DirectMessageChannel"
      super(type_name)
    end

    belongs_to :direct_message,
               -> { where(chat_channels: { chatable_type: "Chat::DirectMessage" }) },
               foreign_key: "chatable_id",
               class_name: "Chat::DirectMessage"
    has_many :chat_messages, class_name: "Chat::Message", foreign_key: :chat_channel_id
    has_many :user_chat_channel_memberships,
             class_name: "Chat::UserChatChannelMembership",
             foreign_key: :chat_channel_id
    has_one :chat_channel_archive, class_name: "Chat::ChannelArchive", foreign_key: :chat_channel_id

    enum :status, { open: 0, read_only: 1, closed: 2, archived: 3 }, scopes: false

    validates :name,
              length: {
                maximum: Proc.new { SiteSetting.max_topic_title_length },
              },
              presence: true,
              allow_nil: true
    validate :ensure_slug_ok, if: :slug_changed?
    before_validation :generate_auto_slug

    scope :public_channels,
          -> {
            where(chatable_type: public_channel_chatable_types).where(
              "categories.id IS NOT NULL",
            ).joins(
              "LEFT JOIN categories ON categories.id = chat_channels.chatable_id AND chat_channels.chatable_type = 'Category'",
            )
          }

    delegate :empty?, to: :chat_messages, prefix: true

    class << self
      def editable_statuses
        statuses.filter { |k, _| !%w[read_only archived].include?(k) }
      end

      def public_channel_chatable_types
        ["Category"]
      end

      def chatable_types
        public_channel_chatable_types << "Chat::DirectMessage"
      end
    end

    statuses.keys.each do |status|
      define_method("#{status}!") { |acting_user| change_status(acting_user, status.to_sym) }
    end

    %i[
      category_channel?
      direct_message_channel?
      public_channel?
      chatable_has_custom_fields?
      read_restricted?
    ].each { |name| define_method(name) { false } }

    %i[allowed_user_ids allowed_group_ids chatable_url].each { |name| define_method(name) { nil } }

    def membership_for(user)
      user_chat_channel_memberships.find_by(user: user)
    end

    def add(user)
      Chat::ChannelMembershipManager.new(self).follow(user)
    end

    def remove(user)
      Chat::ChannelMembershipManager.new(self).unfollow(user)
    end

    def url
      "#{Discourse.base_url}/chat/c/#{self.slug || "-"}/#{self.id}"
    end

    def relative_url
      "#{Discourse.base_path}/chat/c/#{self.slug || "-"}/#{self.id}"
    end

    def self.ensure_consistency!
      update_counts
    end

    # TODO (martin) Move Jobs::Chat::UpdateUserCountsForChannels into here
    def self.update_counts
      # NOTE: Chat::Channel#messages_count is not updated every time
      # a message is created or deleted in a channel, so it should not
      # be displayed in the UI. It is updated eventually via Jobs::Chat::PeriodicalUpdates
      DB.exec <<~SQL
      UPDATE chat_channels channels
      SET messages_count = subquery.messages_count
      FROM (
        SELECT COUNT(*) AS messages_count, chat_channel_id
        FROM chat_messages
        WHERE chat_messages.deleted_at IS NULL
        GROUP BY chat_channel_id
      ) subquery
      WHERE channels.id = subquery.chat_channel_id
      AND channels.deleted_at IS NULL
      AND subquery.messages_count != channels.messages_count
    SQL
    end

    private

    def change_status(acting_user, target_status)
      return if !Guardian.new(acting_user).can_change_channel_status?(self, target_status)
      self.update!(status: target_status)
      log_channel_status_change(acting_user: acting_user)
    end

    def log_channel_status_change(acting_user:)
      DiscourseEvent.trigger(
        :chat_channel_status_change,
        channel: self,
        old_status: status_previously_was,
        new_status: status,
      )

      StaffActionLogger.new(acting_user).log_custom(
        "chat_channel_status_change",
        {
          chat_channel_id: self.id,
          chat_channel_name: self.name,
          previous_value: status_previously_was,
          new_value: status,
        },
      )

      Chat::Publisher.publish_channel_status(self)
    end

    def duplicate_slug?
      Chat::Channel.where(slug: self.slug).where.not(id: self.id).any?
    end
  end
end

# == Schema Information
#
# Table name: chat_channels
#
#  id                           :bigint           not null, primary key
#  chatable_id                  :integer          not null
#  deleted_at                   :datetime
#  deleted_by_id                :integer
#  featured_in_category_id      :integer
#  delete_after_seconds         :integer
#  chatable_type                :string           not null
#  created_at                   :datetime         not null
#  updated_at                   :datetime         not null
#  name                         :string
#  description                  :text
#  status                       :integer          default("open"), not null
#  user_count                   :integer          default(0), not null
#  last_message_sent_at         :datetime         not null
#  auto_join_users              :boolean          default(FALSE), not null
#  allow_channel_wide_mentions  :boolean          default(TRUE), not null
#  user_count_stale             :boolean          default(FALSE), not null
#  slug                         :string
#  type                         :string
#  threading_enabled            :boolean          default(FALSE), not null
#
# Indexes
#
#  index_chat_channels_on_messages_count             (messages_count)
#  index_chat_channels_on_chatable_id                    (chatable_id)
#  index_chat_channels_on_chatable_id_and_chatable_type  (chatable_id,chatable_type)
#  index_chat_channels_on_slug                           (slug) UNIQUE
#  index_chat_channels_on_status                         (status)
#
