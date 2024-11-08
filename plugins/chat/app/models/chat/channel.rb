# frozen_string_literal: true

module Chat
  class Channel < ActiveRecord::Base
    include Trashable
    include TypeMappable
    include HasCustomFields

    # TODO (martin) Remove once we are using last_message instead,
    # should be around August 2023.
    self.ignored_columns = %w[last_message_sent_at]
    self.table_name = "chat_channels"

    belongs_to :chatable, polymorphic: true
    belongs_to :direct_message,
               class_name: "Chat::DirectMessage",
               foreign_key: :chatable_id,
               inverse_of: :direct_message_channel,
               optional: true

    has_many :chat_messages, class_name: "Chat::Message", foreign_key: :chat_channel_id
    has_many :user_chat_channel_memberships,
             class_name: "Chat::UserChatChannelMembership",
             foreign_key: :chat_channel_id
    has_many :threads, class_name: "Chat::Thread", foreign_key: :channel_id
    has_one :chat_channel_archive, class_name: "Chat::ChannelArchive", foreign_key: :chat_channel_id
    belongs_to :last_message,
               class_name: "Chat::Message",
               foreign_key: :last_message_id,
               optional: true
    has_one :icon_upload, class_name: "Upload", foreign_key: :id, primary_key: :icon_upload_id

    def last_message
      super || NullMessage.new
    end

    enum :status, { open: 0, read_only: 1, closed: 2, archived: 3 }, scopes: false

    validates :name,
              length: {
                maximum: Proc.new { SiteSetting.max_topic_title_length },
              },
              presence: true,
              allow_nil: true
    validates :description, length: { maximum: 500 }
    validates :chatable_type, length: { maximum: 100 }
    validates :type, length: { maximum: 100 }
    validates :slug, length: { maximum: 100 }
    validate :ensure_slug_ok, if: :slug_changed?
    before_validation :generate_auto_slug

    scope :with_categories,
          -> do
            joins(
              "LEFT JOIN categories ON categories.id = chat_channels.chatable_id AND chat_channels.chatable_type = 'Category'",
            )
          end
    scope :public_channels,
          -> do
            with_categories.where(chatable_type: public_channel_chatable_types).where(
              "categories.id IS NOT NULL",
            )
          end

    delegate :empty?, to: :chat_messages, prefix: true

    class << self
      def sti_class_mapping =
        {
          "CategoryChannel" => Chat::CategoryChannel,
          "DirectMessageChannel" => Chat::DirectMessageChannel,
        }

      def polymorphic_class_mapping = { "DirectMessage" => Chat::DirectMessage }

      def editable_statuses
        statuses.filter { |k, _| !%w[read_only archived].include?(k) }
      end

      def public_channel_chatable_types
        %w[Category]
      end

      def direct_channel_chatable_types
        %w[DirectMessage]
      end

      def chatable_types
        public_channel_chatable_types + direct_channel_chatable_types
      end

      def find_by_id_or_slug(id)
        with_categories.find_by(
          "chat_channels.id = :id OR categories.slug = :slug OR chat_channels.slug = :slug",
          id: Integer(id, exception: false),
          slug: id.to_s.downcase,
        )
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

    def ensure_slug_ok
      if self.slug.present?
        # if we don't unescape it first we strip the % from the encoded version
        slug = SiteSetting.slug_generation_method == "encoded" ? CGI.unescape(self.slug) : self.slug
        self.slug = Slug.for(slug, "", method: :encoded)

        if self.slug.blank?
          errors.add(:slug, :invalid)
        elsif SiteSetting.slug_generation_method == "ascii" && !CGI.unescape(self.slug).ascii_only?
          errors.add(:slug, I18n.t("chat.category_channel.errors.slug_contains_non_ascii_chars"))
        elsif duplicate_slug?
          errors.add(:slug, I18n.t("chat.category_channel.errors.is_already_in_use"))
        end
      end
    end

    def membership_for(user)
      if user_chat_channel_memberships.loaded?
        user_chat_channel_memberships.detect { |m| m.user_id == user.id }
      else
        user_chat_channel_memberships.find_by(user: user)
      end
    end

    def add(user)
      Chat::ChannelMembershipManager.new(self).follow(user)
    end

    def remove(user)
      Chat::ChannelMembershipManager.new(self).unfollow(user)
    end
    alias leave remove

    def url
      "#{Discourse.base_url}/chat/c/#{self.slug || "-"}/#{self.id}"
    end

    def relative_url
      "#{Discourse.base_path}/chat/c/#{self.slug || "-"}/#{self.id}"
    end

    def update_last_message_id!
      self.update!(last_message_id: self.latest_not_deleted_message_id)
    end

    def self.ensure_consistency!
      update_message_counts
      update_user_counts
    end

    def joined_by?(user)
      user.user_chat_channel_memberships.strict_loading.any? do |membership|
        predicate = membership.chat_channel_id == id
        predicate = predicate && membership.following if public_channel?
        predicate
      end
    end

    def self.update_message_counts
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

    def self.update_user_counts
      updated_channel_ids = DB.query_single(<<~SQL, statuses: [statuses[:open], statuses[:closed]])
        UPDATE chat_channels channels
        SET user_count = subquery.user_count, user_count_stale = false
        FROM (
          SELECT COUNT(DISTINCT user_chat_channel_memberships.id) AS user_count, user_chat_channel_memberships.chat_channel_id
          FROM user_chat_channel_memberships
          INNER JOIN users ON users.id = user_chat_channel_memberships.user_id
          WHERE users.active
            AND (users.suspended_till IS NULL OR users.suspended_till <= CURRENT_TIMESTAMP)
            AND NOT users.staged
            AND user_chat_channel_memberships.following
            and users.id > 0
          GROUP BY user_chat_channel_memberships.chat_channel_id
        ) subquery
        WHERE channels.id = subquery.chat_channel_id
        AND channels.deleted_at IS NULL
        AND subquery.user_count != channels.user_count
        AND channels.status IN (:statuses)
        RETURNING channels.id;
      SQL

      Chat::Channel
        .where(id: updated_channel_ids)
        .find_each { |channel| ::Chat::Publisher.publish_chat_channel_metadata(channel) }
    end

    def latest_not_deleted_message_id(anchor_message_id: nil)
      DB.query_single(<<~SQL, channel_id: self.id, anchor_message_id: anchor_message_id).first
        SELECT chat_messages.id
        FROM chat_messages
        LEFT JOIN chat_threads original_message_threads ON original_message_threads.original_message_id = chat_messages.id
        WHERE chat_channel_id = :channel_id
        AND deleted_at IS NULL
        -- this is so only the original message of a thread is counted not all thread replies
        AND (chat_messages.thread_id IS NULL OR original_message_threads.id IS NOT NULL)
        #{anchor_message_id ? "AND chat_messages.id < :anchor_message_id" : ""}
        ORDER BY chat_messages.created_at DESC, chat_messages.id DESC
        LIMIT 1
      SQL
    end

    def mark_all_threads_as_read(user: nil)
      return if !self.threading_enabled

      DB.exec(<<~SQL, channel_id: self.id)
        UPDATE user_chat_thread_memberships
        SET last_read_message_id = chat_threads.last_message_id
        FROM chat_threads
        WHERE user_chat_thread_memberships.thread_id = chat_threads.id
        #{user ? "AND user_chat_thread_memberships.user_id = #{user.id}" : ""}
        AND (
          user_chat_thread_memberships.last_read_message_id < chat_threads.last_message_id OR
          user_chat_thread_memberships.last_read_message_id IS NULL
        )
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
#  id                          :bigint           not null, primary key
#  chatable_id                 :integer          not null
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
#  type                        :string
#  slug                        :string
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
