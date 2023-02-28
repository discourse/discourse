# frozen_string_literal: true

class ChatMessage < ActiveRecord::Base
  include Trashable
  attribute :has_oneboxes, default: false

  BAKED_VERSION = 2

  belongs_to :chat_channel
  belongs_to :user
  belongs_to :in_reply_to, class_name: "ChatMessage"
  belongs_to :last_editor, class_name: "User"
  belongs_to :thread, class_name: "ChatThread"

  has_many :replies, class_name: "ChatMessage", foreign_key: "in_reply_to_id", dependent: :nullify
  has_many :revisions, class_name: "ChatMessageRevision", dependent: :destroy
  has_many :reactions, class_name: "ChatMessageReaction", dependent: :destroy
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :upload_references, as: :target, dependent: :destroy
  has_many :uploads, through: :upload_references

  # TODO (martin) Remove this when we drop the ChatUpload table
  has_many :chat_uploads, dependent: :destroy
  has_one :chat_webhook_event, dependent: :destroy
  has_many :chat_mentions, dependent: :destroy

  scope :in_public_channel,
        -> {
          joins(:chat_channel).where(
            chat_channel: {
              chatable_type: ChatChannel.public_channel_chatable_types,
            },
          )
        }

  scope :in_dm_channel,
        -> { joins(:chat_channel).where(chat_channel: { chatable_type: "DirectMessage" }) }

  scope :created_before, ->(date) { where("chat_messages.created_at < ?", date) }

  before_save { ensure_last_editor_id }

  def validate_message(has_uploads:)
    WatchedWordsValidator.new(attributes: [:message]).validate(self)

    if self.new_record? || self.changed.include?("message")
      Chat::DuplicateMessageValidator.new(self).validate
    end

    if !has_uploads && message_too_short?
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

  def attach_uploads(uploads)
    return if uploads.blank? || self.new_record?

    now = Time.now
    ref_record_attrs =
      uploads.map do |upload|
        {
          upload_id: upload.id,
          target_id: self.id,
          target_type: "ChatMessage",
          created_at: now,
          updated_at: now,
        }
      end
    UploadReference.insert_all!(ref_record_attrs)
  end

  def excerpt(max_length: 50)
    # just show the URL if the whole message is a URL, because we cannot excerpt oneboxes
    return message if UrlHelper.relaxed_parse(message).is_a?(URI)

    # upload-only messages are better represented as the filename
    return uploads.first.original_filename if cooked.blank? && uploads.present?

    # this may return blank for some complex things like quotes, that is acceptable
    PrettyText.excerpt(cooked, max_length, { text_entities: true })
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
  end

  def rebake!(invalidate_oneboxes: false, priority: nil)
    ensure_last_editor_id

    previous_cooked = self.cooked
    new_cooked =
      self.class.cook(
        message,
        invalidate_oneboxes: invalidate_oneboxes,
        user_id: self.last_editor_id,
      )
    update_columns(cooked: new_cooked, cooked_version: BAKED_VERSION)
    args = { chat_message_id: self.id }
    args[:queue] = priority.to_s if priority && priority != :normal
    args[:is_dirty] = true if previous_cooked != new_cooked

    Jobs.enqueue(:process_chat_message, args)
  end

  def self.uncooked
    where("cooked_version <> ? or cooked_version IS NULL", BAKED_VERSION)
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
  ]

  def self.cook(message, opts = {})
    # A rule in our Markdown pipeline may have Guardian checks that require a
    # user to be present. The last editing user of the message will be more
    # generally up to date than the creating user. For example, we use
    # this when cooking #hashtags to determine whether we should render
    # the found hashtag based on whether the user can access the channel it
    # is referencing.
    cooked =
      PrettyText.cook(
        message,
        features_override: MARKDOWN_FEATURES + DiscoursePluginRegistry.chat_markdown_features.to_a,
        markdown_it_rules: MARKDOWN_IT_RULES,
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
    "#{Discourse.base_url}#{url}"
  end

  def url
    "/chat/message/#{self.id}"
  end

  def create_mentions(user_ids)
    return if user_ids.empty?

    now = Time.zone.now
    mentions = []
    User
      .where(id: user_ids)
      .find_each do |user|
        mentions << { chat_message_id: self.id, user_id: user.id, created_at: now, updated_at: now }
      end

    ChatMention.insert_all(mentions)
  end

  def update_mentions(mentioned_user_ids)
    old_mentions = chat_mentions.pluck(:user_id)
    updated_mentions = mentioned_user_ids
    mentioned_user_ids_to_drop = old_mentions - updated_mentions
    mentioned_user_ids_to_add = updated_mentions - old_mentions

    delete_mentions(mentioned_user_ids_to_drop)
    create_mentions(mentioned_user_ids_to_add)
  end

  private

  def delete_mentions(user_ids)
    chat_mentions.where(user_id: user_ids).destroy_all
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
#  index_chat_messages_on_chat_channel_id_and_created_at  (chat_channel_id,created_at)
#  index_chat_messages_on_chat_channel_id_and_id          (chat_channel_id,id) WHERE (deleted_at IS NULL)
#  index_chat_messages_on_last_editor_id                  (last_editor_id)
#  index_chat_messages_on_thread_id                       (thread_id)
#
