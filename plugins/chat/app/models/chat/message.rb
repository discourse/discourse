# frozen_string_literal: true

module Chat
  class Message < ActiveRecord::Base
    include Trashable
    include TypeMappable
    include HasCustomFields

    self.table_name = "chat_messages"

    BAKED_VERSION = 2
    EXCERPT_LENGTH = 150

    attribute :has_oneboxes, default: false

    belongs_to :chat_channel, class_name: "Chat::Channel"
    belongs_to :user
    belongs_to :in_reply_to, class_name: "Chat::Message", autosave: true
    belongs_to :last_editor, class_name: "User"
    belongs_to :thread, class_name: "Chat::Thread", optional: true, autosave: true

    has_many :interactions,
             class_name: "Chat::MessageInteraction",
             dependent: :destroy,
             foreign_key: :chat_message_id
    has_many :replies,
             class_name: "Chat::Message",
             foreign_key: "in_reply_to_id",
             dependent: :nullify
    has_many :revisions,
             class_name: "Chat::MessageRevision",
             dependent: :destroy,
             foreign_key: :chat_message_id
    has_many :reactions,
             class_name: "Chat::MessageReaction",
             dependent: :destroy,
             foreign_key: :chat_message_id
    has_many :bookmarks,
             -> do
               unscope(where: :bookmarkable_type).where(
                 bookmarkable_type: Chat::Message.polymorphic_name,
               )
             end,
             as: :bookmarkable,
             dependent: :destroy
    has_many :upload_references,
             -> { unscope(where: :target_type).where(target_type: Chat::Message.polymorphic_name) },
             dependent: :destroy,
             foreign_key: :target_id
    has_many :uploads, through: :upload_references, class_name: "::Upload"

    has_one :chat_webhook_event,
            dependent: :destroy,
            class_name: "Chat::WebhookEvent",
            foreign_key: :chat_message_id
    has_many :chat_mentions,
             dependent: :destroy,
             class_name: "Chat::Mention",
             foreign_key: :chat_message_id
    has_many :user_mentions,
             dependent: :destroy,
             class_name: "Chat::UserMention",
             foreign_key: :chat_message_id
    has_many :group_mentions,
             dependent: :destroy,
             class_name: "Chat::GroupMention",
             foreign_key: :chat_message_id
    has_one :all_mention,
            dependent: :destroy,
            class_name: "Chat::AllMention",
            foreign_key: :chat_message_id
    has_one :here_mention,
            dependent: :destroy,
            class_name: "Chat::HereMention",
            foreign_key: :chat_message_id

    scope :in_public_channel,
          -> do
            joins(:chat_channel).where(
              chat_channel: {
                chatable_type: Chat::Channel.public_channel_chatable_types,
              },
            )
          end
    scope :in_dm_channel,
          -> do
            joins(:chat_channel).where(
              chat_channel: {
                chatable_type: Chat::Channel.direct_channel_chatable_types,
              },
            )
          end
    scope :created_before, ->(date) { where("chat_messages.created_at < ?", date) }
    scope :uncooked, -> { where("cooked_version <> ? or cooked_version IS NULL", BAKED_VERSION) }

    before_save { ensure_last_editor_id }

    normalizes :blocks,
               with: ->(blocks) do
                 return if !blocks

                 # automatically assigns unique IDs
                 blocks.each do |block|
                   block["block_id"] = SecureRandom.uuid if !block["block_id"]
                   block["elements"].each do |element|
                     element["action_id"] = SecureRandom.uuid if element["type"] == "button" &&
                       !element["action_id"]
                   end
                 end
               end

    validates :cooked, length: { maximum: 20_000 }

    validate :validate_blocks
    def validate_blocks
      return if !blocks

      schemer = JSONSchemer.schema(Chat::Schemas::MessageBlocks)
      if !schemer.valid?(blocks)
        errors.add(:blocks, schemer.validate(blocks).map { _1.fetch("error") })
        return
      end

      block_ids = Set.new
      action_ids = Set.new
      blocks.each do |block|
        block_id = block["block_id"]
        if block_ids.include?(block_id)
          errors.add(:blocks, "have duplicated block_id: #{block_id}")
          next
        end
        block_ids.add(block_id)

        block["elements"].each do |element|
          action_id = element["action_id"]
          next unless action_id
          if action_ids.include?(action_id)
            errors.add(:elements, "have duplicated action_id: #{action_id}")
            next
          end
          action_ids.add(action_id)
        end
      end
    end

    def self.polymorphic_class_mapping = { "ChatMessage" => Chat::Message }

    validate :validate_message
    def validate_message
      WatchedWordsValidator.new(attributes: [:message]).validate(self)

      if self.new_record? || self.changed.include?("message")
        Chat::DuplicateMessageValidator.new(self).validate
      end

      if uploads.empty? && message_too_short?
        self.errors.add(
          :base,
          I18n.t(
            "chat.errors.minimum_length_not_met",
            count: SiteSetting.chat_minimum_message_length,
          ),
        )
      end

      if message_too_long?
        self.errors.add(
          :base,
          I18n.t("chat.errors.message_too_long", count: SiteSetting.chat_maximum_message_length),
        )
      end
    end

    def build_excerpt
      # just show the URL if the whole message is a URL, because we cannot excerpt oneboxes
      urls = PrettyText.extract_links(cooked).map(&:url)
      if urls.present?
        regex = %r{^[^:]+://}
        clean_urls = urls.map { |url| url.sub(regex, "") }
        if message.gsub(regex, "").split.sort == clean_urls.sort
          return PrettyText.excerpt(urls.join(" "), EXCERPT_LENGTH)
        end
      end

      # upload-only messages are better represented as the filename
      return uploads.first.original_filename if cooked.blank? && uploads.present?

      # this may return blank for some complex things like quotes, that is acceptable
      PrettyText.excerpt(cooked, EXCERPT_LENGTH, strip_links: true, keep_mentions: true)
    end

    def cooked_for_excerpt
      (cooked.blank? && uploads.present?) ? "<p>#{uploads.first.original_filename}</p>" : cooked
    end

    def push_notification_excerpt
      Emoji.gsub_emoji_to_unicode(message).truncate(400)
    end

    def to_markdown
      upload_markdown =
        self
          .upload_references
          .includes(:upload)
          .order(:created_at)
          .map(&:to_markdown)
          .reject(&:empty?)

      return self.message if upload_markdown.empty?

      return ["#{self.message}\n"].concat(upload_markdown).join("\n") if self.message.present?

      upload_markdown.join("\n")
    end

    def cook
      ensure_last_editor_id

      self.cooked = self.class.cook(self.message, user_id: self.last_editor_id)
      self.cooked_version = BAKED_VERSION

      invalidate_parsed_mentions
    end

    def rebake!(invalidate_oneboxes: false, priority: nil)
      ensure_last_editor_id
      args = { chat_message_id: self.id, invalidate_oneboxes: invalidate_oneboxes }
      args[:queue] = priority.to_s if priority && priority != :normal
      Jobs.enqueue(Jobs::Chat::ProcessMessage, args)
    end

    MARKDOWN_FEATURES = %w[
      anchor
      bbcode-block
      bbcode-inline
      code
      category-hashtag
      censored
      chat-transcript
      discourse-local-dates
      emoji
      emojiShortcuts
      inlineEmoji
      html-img
      hashtag-autocomplete
      mentions
      unicodeUsernames
      onebox
      quotes
      spoiler-alert
      table
      text-post-process
      upload-protocol
      watched-words
      chat-html-inline
    ]

    MARKDOWN_IT_RULES = %w[
      autolink
      list
      backticks
      newline
      code
      fence
      image
      table
      linkify
      link
      strikethrough
      blockquote
      emphasis
      replacements
      escape
    ]

    def self.cook(message, opts = {})
      bot = opts[:user_id] && opts[:user_id].negative?

      features = MARKDOWN_FEATURES.dup
      features << "image-grid" if bot

      rules = MARKDOWN_IT_RULES.dup
      rules << "heading" if bot

      # A rule in our Markdown pipeline may have Guardian checks that require a
      # user to be present. The last editing user of the message will be more
      # generally up to date than the creating user. For example, we use
      # this when cooking #hashtags to determine whether we should render
      # the found hashtag based on whether the user can access the channel it
      # is referencing.
      cooked =
        PrettyText.cook(
          message,
          features_override: features + DiscoursePluginRegistry.chat_markdown_features.to_a,
          markdown_it_rules: rules,
          force_quote_link: true,
          user_id: opts[:user_id],
          hashtag_context: "chat-composer",
        )

      result =
        Oneboxer.apply(cooked) do |url|
          if opts[:invalidate_oneboxes]
            Oneboxer.invalidate(url)
            InlineOneboxer.invalidate(url)
          end
          onebox = Oneboxer.cached_onebox(url)
          onebox
        end

      cooked = result.to_html if result.changed?
      cooked
    end

    def full_url
      "#{Discourse.base_url_no_prefix}#{url}"
    end

    def url
      if in_thread?
        "#{Discourse.base_path}/chat/c/-/#{self.chat_channel_id}/t/#{self.thread_id}/#{self.id}"
      else
        "#{Discourse.base_path}/chat/c/-/#{self.chat_channel_id}/#{self.id}"
      end
    end

    def upsert_mentions
      upsert_user_mentions
      upsert_group_mentions
      create_or_delete_all_mention
      create_or_delete_here_mention
    end

    def in_thread?
      self.thread_id.present? && (self.chat_channel.threading_enabled || self.thread&.force)
    end

    def thread_reply?
      in_thread? && !thread_om?
    end

    def thread_om?
      in_thread? && self.thread&.original_message_id == self.id
    end

    def parsed_mentions
      @parsed_mentions ||= Chat::ParsedMentions.new(self)
    end

    def invalidate_parsed_mentions
      @parsed_mentions = nil
    end

    private

    def delete_mentions(mention_type, target_ids)
      chat_mentions.where(type: mention_type, target_id: target_ids).destroy_all
    end

    def insert_mentions(type, target_ids)
      return if target_ids.empty?

      mentions =
        target_ids.map do |target_id|
          { chat_message_id: self.id, target_id: target_id, type: type }
        end

      Chat::Mention.insert_all(mentions)
    end

    def message_too_short?
      message.length < SiteSetting.chat_minimum_message_length
    end

    def message_too_long?
      message.length > SiteSetting.chat_maximum_message_length
    end

    def ensure_last_editor_id
      self.last_editor_id ||= self.user_id
    end

    def create_or_delete_all_mention
      if !parsed_mentions.has_global_mention && all_mention.present?
        all_mention.destroy!
        association(:all_mention).reload
      elsif parsed_mentions.has_global_mention && all_mention.blank?
        build_all_mention.save!
      end
    end

    def create_or_delete_here_mention
      if !parsed_mentions.has_here_mention && here_mention.present?
        here_mention.destroy!
        association(:here_mention).reload
      elsif parsed_mentions.has_here_mention && here_mention.blank?
        build_here_mention.save!
      end
    end

    def upsert_group_mentions
      old_mentions = group_mentions.pluck(:target_id)
      new_mentions = parsed_mentions.groups_to_mention.pluck(:id)
      delete_mentions("Chat::GroupMention", old_mentions - new_mentions)
      insert_mentions("Chat::GroupMention", new_mentions - old_mentions)
    end

    def upsert_user_mentions
      old_mentions = user_mentions.pluck(:target_id)
      new_mentions = parsed_mentions.direct_mentions.pluck(:id)
      delete_mentions("Chat::UserMention", old_mentions - new_mentions)
      insert_mentions("Chat::UserMention", new_mentions - old_mentions)
    end
  end
end

# == Schema Information
#
# Table name: chat_messages
#
#  id              :bigint           not null, primary key
#  chat_channel_id :integer          not null
#  user_id         :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  deleted_at      :datetime
#  deleted_by_id   :integer
#  in_reply_to_id  :integer
#  message         :text
#  cooked          :text
#  cooked_version  :integer
#  last_editor_id  :integer          not null
#  thread_id       :integer
#
# Indexes
#
#  idx_chat_messages_by_created_at_not_deleted            (created_at) WHERE (deleted_at IS NULL)
#  idx_chat_messages_by_thread_id_not_deleted             (thread_id) WHERE (deleted_at IS NULL)
#  index_chat_messages_on_chat_channel_id_and_created_at  (chat_channel_id,created_at)
#  index_chat_messages_on_chat_channel_id_and_id          (chat_channel_id,id) WHERE (deleted_at IS NULL)
#  index_chat_messages_on_last_editor_id                  (last_editor_id)
#  index_chat_messages_on_thread_id                       (thread_id)
#
