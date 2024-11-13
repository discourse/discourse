# frozen_string_literal: true

class Topic < ActiveRecord::Base
  class UserExists < StandardError
  end

  class NotAllowed < StandardError
  end
  include RateLimiter::OnCreateRecord
  include HasCustomFields
  include Trashable
  include Searchable
  include LimitedEdit
  extend Forwardable

  EXTERNAL_ID_MAX_LENGTH = 50

  self.ignored_columns = [
    "avg_time", # TODO: Remove when 20240212034010_drop_deprecated_columns has been promoted to pre-deploy
    "image_url", # TODO: Remove when 20240212034010_drop_deprecated_columns has been promoted to pre-deploy
  ]

  def_delegator :featured_users, :user_ids, :featured_user_ids
  def_delegator :featured_users, :choose, :feature_topic_users

  def_delegator :notifier, :watch!, :notify_watch!
  def_delegator :notifier, :track!, :notify_tracking!
  def_delegator :notifier, :regular!, :notify_regular!
  def_delegator :notifier, :mute!, :notify_muted!
  def_delegator :notifier, :toggle_mute, :toggle_mute

  attr_accessor :allowed_user_ids, :allowed_group_ids, :tags_changed, :includes_destination_category

  def self.max_fancy_title_length
    400
  end

  def self.share_thumbnail_size
    [1024, 1024]
  end

  def self.thumbnail_sizes
    [self.share_thumbnail_size] + DiscoursePluginRegistry.topic_thumbnail_sizes
  end

  def self.visibility_reasons
    @visible_reasons ||=
      Enum.new(
        op_flag_threshold_reached: 0,
        op_unhidden: 1,
        embedded_topic: 2,
        manually_unlisted: 3,
        manually_relisted: 4,
        bulk_action: 5,
        unknown: 99,
      )
  end

  def shared_draft?
    SharedDraft.exists?(topic_id: id)
  end

  def thumbnail_job_redis_key(sizes)
    "generate_topic_thumbnail_enqueue_#{id}_#{sizes.inspect}"
  end

  def filtered_topic_thumbnails(extra_sizes: [])
    return nil unless original = image_upload
    return nil unless original.read_attribute(:width) && original.read_attribute(:height)

    thumbnail_sizes = Topic.thumbnail_sizes + extra_sizes
    topic_thumbnails.filter do |record|
      thumbnail_sizes.include?([record.max_width, record.max_height])
    end
  end

  def thumbnail_info(enqueue_if_missing: false, extra_sizes: [])
    return nil unless original = image_upload
    return nil if original.filesize >= SiteSetting.max_image_size_kb.to_i.kilobytes
    return nil unless original.read_attribute(:width) && original.read_attribute(:height)

    infos = []
    infos << { # Always add original
      max_width: nil,
      max_height: nil,
      width: original.width,
      height: original.height,
      url: original.url,
    }

    records = filtered_topic_thumbnails(extra_sizes: extra_sizes)

    records.each do |record|
      next unless record.optimized_image # Only serialize successful thumbnails

      infos << {
        max_width: record.max_width,
        max_height: record.max_height,
        width: record.optimized_image&.width,
        height: record.optimized_image&.height,
        url: record.optimized_image&.url,
      }
    end

    thumbnail_sizes = Topic.thumbnail_sizes + extra_sizes
    if SiteSetting.create_thumbnails && enqueue_if_missing &&
         records.length < thumbnail_sizes.length &&
         Discourse.redis.set(thumbnail_job_redis_key(extra_sizes), 1, nx: true, ex: 1.minute)
      Jobs.enqueue(:generate_topic_thumbnails, { topic_id: id, extra_sizes: extra_sizes })
    end

    infos.each { |i| i[:url] = UrlHelper.cook_url(i[:url], secure: original.secure?, local: true) }

    infos.sort_by! { |i| -i[:width] * i[:height] }
  end

  def generate_thumbnails!(extra_sizes: [])
    return nil unless SiteSetting.create_thumbnails
    return nil unless original = image_upload
    return nil if original.filesize >= SiteSetting.max_image_size_kb.kilobytes
    return nil unless original.width && original.height
    extra_sizes = [] unless extra_sizes.kind_of?(Array)

    (Topic.thumbnail_sizes + extra_sizes).each do |dim|
      TopicThumbnail.find_or_create_for!(original, max_width: dim[0], max_height: dim[1])
    end
  end

  def image_url(enqueue_if_missing: false)
    thumbnail =
      topic_thumbnails.detect do |record|
        record.max_width == Topic.share_thumbnail_size[0] &&
          record.max_height == Topic.share_thumbnail_size[1]
      end

    if thumbnail.nil? && image_upload && SiteSetting.create_thumbnails &&
         image_upload.filesize < SiteSetting.max_image_size_kb.kilobytes &&
         image_upload.read_attribute(:width) && image_upload.read_attribute(:height) &&
         enqueue_if_missing &&
         Discourse.redis.set(thumbnail_job_redis_key([]), 1, nx: true, ex: 1.minute)
      Jobs.enqueue(:generate_topic_thumbnails, { topic_id: id })
    end

    raw_url = thumbnail&.optimized_image&.url || image_upload&.url
    UrlHelper.cook_url(raw_url, secure: image_upload&.secure?, local: true) if raw_url
  end

  def featured_users
    @featured_users ||= TopicFeaturedUsers.new(self)
  end

  def trash!(trashed_by = nil)
    trigger_event = false

    if deleted_at.nil?
      update_category_topic_count_by(-1) if visible?
      CategoryTagStat.topic_deleted(self) if self.tags.present?
      trigger_event = true
    end

    super(trashed_by)

    DiscourseEvent.trigger(:topic_trashed, self) if trigger_event

    self.topic_embed.trash! if has_topic_embed?
  end

  def recover!(recovered_by = nil)
    trigger_event = false

    unless deleted_at.nil?
      update_category_topic_count_by(1) if visible?
      CategoryTagStat.topic_recovered(self) if self.tags.present?
      trigger_event = true
    end

    # Note parens are required because superclass doesn't take `recovered_by`
    super()

    DiscourseEvent.trigger(:topic_recovered, self) if trigger_event

    unless (topic_embed = TopicEmbed.with_deleted.find_by_topic_id(id)).nil?
      topic_embed.recover!
    end
  end

  rate_limit :default_rate_limiter
  rate_limit :limit_topics_per_day
  rate_limit :limit_private_messages_per_day

  validates :title,
            if: Proc.new { |t| t.new_record? || t.title_changed? || t.category_id_changed? },
            presence: true,
            topic_title_length: true,
            censored_words: true,
            watched_words: true,
            quality_title: {
              unless: :private_message?,
            },
            max_emojis: true,
            unique_among: {
              unless:
                Proc.new { |t| (SiteSetting.allow_duplicate_topic_titles? || t.private_message?) },
              message: :has_already_been_used,
              allow_blank: true,
              case_sensitive: false,
              collection:
                Proc.new { |t|
                  if SiteSetting.allow_duplicate_topic_titles_category?
                    Topic.listable_topics.where("category_id = ?", t.category_id)
                  else
                    Topic.listable_topics
                  end
                },
            }

  validates :category_id,
            presence: true,
            exclusion: {
              in: Proc.new { [SiteSetting.uncategorized_category_id] },
            },
            if:
              Proc.new { |t|
                (t.new_record? || t.category_id_changed?) &&
                  !SiteSetting.allow_uncategorized_topics && (t.archetype.nil? || t.regular?)
              }

  validates :featured_link, allow_nil: true, url: true
  validate if: :featured_link do
    if featured_link_changed? && !Guardian.new(user).can_edit_featured_link?(category_id)
      errors.add(:featured_link)
    end
  end

  validates :external_id,
            allow_nil: true,
            uniqueness: {
              case_sensitive: false,
            },
            length: {
              maximum: EXTERNAL_ID_MAX_LENGTH,
            },
            format: {
              with: /\A[\w-]+\z/,
            }

  before_validation do
    self.title = TextCleaner.clean_title(TextSentinel.title_sentinel(title).text) if errors[
      :title
    ].empty?
    self.featured_link = self.featured_link.strip.presence if self.featured_link
  end

  belongs_to :category
  has_many :category_users, through: :category
  has_many :posts

  # NOTE: To get all Post _and_ Topic bookmarks for a topic by user,
  # use the Bookmark.for_user_in_topic scope.
  has_many :bookmarks, as: :bookmarkable

  has_many :ordered_posts, -> { order(post_number: :asc) }, class_name: "Post"
  has_many :topic_allowed_users
  has_many :topic_allowed_groups
  has_many :incoming_email

  has_many :group_archived_messages, dependent: :destroy
  has_many :user_archived_messages, dependent: :destroy
  has_many :topic_view_stats, dependent: :destroy

  has_many :allowed_groups, through: :topic_allowed_groups, source: :group
  has_many :allowed_group_users, through: :allowed_groups, source: :users
  has_many :allowed_users, through: :topic_allowed_users, source: :user

  has_many :topic_tags
  has_many :tags, through: :topic_tags, dependent: :destroy # dependent destroy applies to the topic_tags records
  has_many :tag_users, through: :tags

  has_many :moved_posts_as_old_topic,
           class_name: "MovedPost",
           foreign_key: :old_topic_id,
           dependent: :destroy
  has_many :moved_posts_as_new_topic,
           class_name: "MovedPost",
           foreign_key: :new_topic_id,
           dependent: :destroy

  has_one :top_topic
  has_one :shared_draft, dependent: :destroy
  has_one :published_page

  belongs_to :user
  belongs_to :last_poster, class_name: "User", foreign_key: :last_post_user_id
  belongs_to :featured_user1, class_name: "User", foreign_key: :featured_user1_id
  belongs_to :featured_user2, class_name: "User", foreign_key: :featured_user2_id
  belongs_to :featured_user3, class_name: "User", foreign_key: :featured_user3_id
  belongs_to :featured_user4, class_name: "User", foreign_key: :featured_user4_id

  has_many :topic_users
  has_many :dismissed_topic_users
  has_many :topic_links
  has_many :topic_invites
  has_many :invites, through: :topic_invites, source: :invite
  has_many :topic_timers, dependent: :destroy
  has_many :reviewables
  has_many :user_profiles

  has_one :user_warning
  has_one :first_post, -> { where post_number: 1 }, class_name: "Post"
  has_one :topic_search_data
  has_one :topic_embed, dependent: :destroy
  has_one :linked_topic, dependent: :destroy

  belongs_to :image_upload, class_name: "Upload"
  has_many :topic_thumbnails, through: :image_upload

  # When we want to temporarily attach some data to a forum topic (usually before serialization)
  attr_accessor :user_data
  attr_accessor :category_user_data
  attr_accessor :dismissed

  attr_accessor :posters # TODO: can replace with posters_summary once we remove old list code
  attr_accessor :participants
  attr_accessor :participant_groups
  attr_accessor :topic_list
  attr_accessor :include_last_poster
  attr_accessor :import_mode # set to true to optimize creation and save for imports

  # The regular order
  scope :topic_list_order, -> { order("topics.bumped_at desc") }

  # Return private message topics
  scope :private_messages, -> { where(archetype: Archetype.private_message) }

  PRIVATE_MESSAGES_SQL_USER = <<~SQL
    SELECT topic_id
    FROM topic_allowed_users
    WHERE user_id = :user_id
  SQL

  PRIVATE_MESSAGES_SQL_GROUP = <<~SQL
    SELECT tg.topic_id
    FROM topic_allowed_groups tg
    JOIN group_users gu ON gu.user_id = :user_id AND gu.group_id = tg.group_id
  SQL

  scope :private_messages_for_user,
        ->(user) do
          private_messages.where(
            "topics.id IN (#{PRIVATE_MESSAGES_SQL_USER})
      OR topics.id IN (#{PRIVATE_MESSAGES_SQL_GROUP})",
            user_id: user.id,
          )
        end

  scope :listable_topics, -> { where("topics.archetype <> ?", Archetype.private_message) }

  scope :by_newest, -> { order("topics.created_at desc, topics.id desc") }

  scope :visible, -> { where(visible: true) }

  scope :created_since, lambda { |time_ago| where("topics.created_at > ?", time_ago) }

  scope :exclude_scheduled_bump_topics, -> { where.not(id: TopicTimer.scheduled_bump_topics) }

  scope :secured,
        lambda { |guardian = nil|
          ids = guardian.secure_category_ids if guardian

          # Query conditions
          condition =
            if ids.present?
              ["NOT read_restricted OR id IN (:cats)", cats: ids]
            else
              ["NOT read_restricted"]
            end

          where(
            "topics.category_id IS NULL OR topics.category_id IN (SELECT id FROM categories WHERE #{condition[0]})",
            condition[1],
          )
        }

  scope :in_category_and_subcategories,
        lambda { |category_id|
          if category_id
            where("topics.category_id IN (?)", Category.subcategory_ids(category_id.to_i))
          end
        }

  scope :with_subtype, ->(subtype) { where("topics.subtype = ?", subtype) }

  attr_accessor :ignore_category_auto_close
  attr_accessor :skip_callbacks
  attr_accessor :advance_draft

  before_create { initialize_default_values }

  after_create do
    unless skip_callbacks
      changed_to_category(category)
      advance_draft_sequence if advance_draft
    end
  end

  before_save do
    ensure_topic_has_a_category unless skip_callbacks

    write_attribute(:fancy_title, Topic.fancy_title(title)) if title_changed?

    if category_id_changed? || new_record?
      inherit_auto_close_from_category
      inherit_slow_mode_from_category
    end
  end

  after_save do
    banner = "banner"

    if archetype_before_last_save == banner || archetype == banner
      ApplicationController.banner_json_cache.clear
    end

    if tags_changed || saved_change_to_attribute?(:category_id) ||
         saved_change_to_attribute?(:title)
      SearchIndexer.queue_post_reindex(self.id)

      if tags_changed
        TagUser.auto_watch(topic_id: id)
        TagUser.auto_track(topic_id: id)
        self.tags_changed = false
      end
    end

    SearchIndexer.index(self)
  end

  after_update do
    if saved_changes[:category_id] && self.tags.present?
      CategoryTagStat.topic_moved(self, *saved_changes[:category_id])
    elsif saved_changes[:category_id] && self.category&.read_restricted?
      UserProfile.remove_featured_topic_from_all_profiles(self)
    end
  end

  def initialize_default_values
    self.bumped_at ||= Time.now
    self.last_post_user_id ||= user_id
  end

  def advance_draft_sequence
    if self.private_message?
      DraftSequence.next!(user, Draft::NEW_PRIVATE_MESSAGE)
    else
      DraftSequence.next!(user, Draft::NEW_TOPIC)
    end
  end

  def ensure_topic_has_a_category
    if category_id.nil? && (archetype.nil? || self.regular?)
      self.category_id = category&.id || SiteSetting.uncategorized_category_id
    end
  end

  def self.visible_post_types(viewed_by = nil, include_moderator_actions: true)
    types = Post.types
    result = [types[:regular]]
    result += [types[:moderator_action], types[:small_action]] if include_moderator_actions
    result << types[:whisper] if viewed_by&.whisperer?
    result
  end

  def self.top_viewed(max = 10)
    Topic.listable_topics.visible.secured.order("views desc").limit(max)
  end

  def self.recent(max = 10)
    Topic.listable_topics.visible.secured.order("created_at desc").limit(max)
  end

  def self.count_exceeds_minimum?
    count > SiteSetting.minimum_topics_similar
  end

  def best_post
    posts
      .where(post_type: Post.types[:regular], user_deleted: false)
      .order("score desc nulls last")
      .limit(1)
      .first
  end

  def self.has_flag_scope
    ReviewableFlaggedPost.pending_and_default_visible
  end

  def has_flags?
    self.class.has_flag_scope.exists?(topic_id: self.id)
  end

  def is_official_warning?
    subtype == TopicSubtype.moderator_warning
  end

  # all users (in groups or directly targeted) that are going to get the pm
  def all_allowed_users
    moderators_sql = " UNION #{User.moderators.to_sql}" if private_message? &&
      (has_flags? || is_official_warning?)
    User.from(
      "(#{allowed_users.to_sql} UNION #{allowed_group_users.to_sql}#{moderators_sql}) as users",
    )
  end

  # Additional rate limits on topics: per day and private messages per day
  def limit_topics_per_day
    return unless regular?
    if user && user.new_user_posting_on_first_day?
      limit_first_day_topics_per_day
    else
      apply_per_day_rate_limit_for("topics", :max_topics_per_day)
    end
  end

  def limit_private_messages_per_day
    return unless private_message?
    apply_per_day_rate_limit_for("pms", :max_personal_messages_per_day)
  end

  def self.fancy_title(title)
    return unless escaped = ERB::Util.html_escape(title)
    fancy_title = Emoji.unicode_unescape(HtmlPrettify.render(escaped))
    fancy_title.length > Topic.max_fancy_title_length ? escaped : fancy_title
  end

  def fancy_title
    return ERB::Util.html_escape(title) unless SiteSetting.title_fancy_entities?

    unless fancy_title = read_attribute(:fancy_title)
      fancy_title = Topic.fancy_title(title)
      write_attribute(:fancy_title, fancy_title)

      if !new_record? && !Discourse.readonly_mode?
        # make sure data is set in table, this also allows us to change algorithm
        # by simply nulling this column
        DB.exec(
          "UPDATE topics SET fancy_title = :fancy_title where id = :id",
          id: self.id,
          fancy_title: fancy_title,
        )
      end
    end

    fancy_title
  end

  # Returns hot topics since a date for display in email digest.
  def self.for_digest(user, since, opts = nil)
    opts ||= {}

    period = ListController.best_period_for(since)

    topics =
      Topic
        .visible
        .secured(Guardian.new(user))
        .joins(
          "LEFT OUTER JOIN topic_users ON topic_users.topic_id = topics.id AND topic_users.user_id = #{user.id.to_i}",
        )
        .joins(
          "LEFT OUTER JOIN category_users ON category_users.category_id = topics.category_id AND category_users.user_id = #{user.id.to_i}",
        )
        .joins("LEFT OUTER JOIN users ON users.id = topics.user_id")
        .where(closed: false, archived: false)
        .where(
          "COALESCE(topic_users.notification_level, 1) <> ?",
          TopicUser.notification_levels[:muted],
        )
        .created_since(since)
        .where("topics.created_at < ?", (SiteSetting.editing_grace_period || 0).seconds.ago)
        .listable_topics
        .includes(:category)

    unless opts[:include_tl0] || user.user_option.try(:include_tl0_in_digests)
      topics = topics.where("COALESCE(users.trust_level, 0) > 0")
    end

    if !!opts[:top_order]
      topics =
        topics.joins("LEFT OUTER JOIN top_topics ON top_topics.topic_id = topics.id").order(<<~SQL)
          COALESCE(topic_users.notification_level, 1) DESC,
          COALESCE(category_users.notification_level, 1) DESC,
          COALESCE(top_topics.#{TopTopic.score_column_for_period(period)}, 0) DESC,
          topics.bumped_at DESC
      SQL
    end

    topics = topics.limit(opts[:limit]) if opts[:limit]

    # Remove category topics
    topics = topics.where.not(id: Category.select(:topic_id).where.not(topic_id: nil))

    # Remove suppressed categories
    if SiteSetting.digest_suppress_categories.present?
      topics =
        topics.where.not(category_id: SiteSetting.digest_suppress_categories.split("|").map(&:to_i))
    end

    # Remove suppressed tags
    if SiteSetting.digest_suppress_tags.present?
      tag_ids = Tag.where_name(SiteSetting.digest_suppress_tags.split("|")).pluck(:id)

      topics =
        topics.where.not(id: TopicTag.where(tag_id: tag_ids).select(:topic_id)) if tag_ids.present?
    end

    # Remove muted and shared draft categories
    remove_category_ids =
      CategoryUser.where(
        user_id: user.id,
        notification_level: CategoryUser.notification_levels[:muted],
      ).pluck(:category_id)

    remove_category_ids << SiteSetting.shared_drafts_category if SiteSetting.shared_drafts_enabled?

    if remove_category_ids.present?
      remove_category_ids.uniq!
      topics =
        topics.where(
          "topic_users.notification_level != ? OR topics.category_id NOT IN (?)",
          TopicUser.notification_levels[:muted],
          remove_category_ids,
        )
    end

    # Remove muted tags
    muted_tag_ids = TagUser.lookup(user, :muted).pluck(:tag_id)
    unless muted_tag_ids.empty?
      # If multiple tags per topic, include topics with tags that aren't muted,
      # and don't forget untagged topics.
      topics =
        topics.where(
          "EXISTS ( SELECT 1 FROM topic_tags WHERE topic_tags.topic_id = topics.id AND tag_id NOT IN (?) )
        OR NOT EXISTS (SELECT 1 FROM topic_tags WHERE topic_tags.topic_id = topics.id)",
          muted_tag_ids,
        )
    end

    topics
  end

  def reload(options = nil)
    @post_numbers = nil
    @public_topic_timer = nil
    @slow_mode_topic_timer = nil
    @is_category_topic = nil
    super(options)
  end

  def post_numbers
    @post_numbers ||= posts.order(:post_number).pluck(:post_number)
  end

  def age_in_minutes
    ((Time.zone.now - created_at) / 1.minute).round
  end

  def self.listable_count_per_day(
    start_date,
    end_date,
    category_id = nil,
    include_subcategories = false,
    group_ids = nil
  )
    result =
      listable_topics.where(
        "topics.created_at >= ? AND topics.created_at <= ?",
        start_date,
        end_date,
      )
    result = result.group("date(topics.created_at)").order("date(topics.created_at)")
    result =
      result.where(
        category_id: include_subcategories ? Category.subcategory_ids(category_id) : category_id,
      ) if category_id

    if group_ids
      result =
        result
          .joins("INNER JOIN users ON users.id = topics.user_id")
          .joins("INNER JOIN group_users ON group_users.user_id = users.id")
          .where("group_users.group_id IN (?)", group_ids)
    end

    result.count
  end

  def private_message?
    self.archetype == Archetype.private_message
  end

  def regular?
    self.archetype == Archetype.default
  end

  def open?
    !self.closed?
  end

  MAX_SIMILAR_BODY_LENGTH = 200

  def self.similar_to(title, raw, user = nil)
    return [] if SiteSetting.max_similar_results == 0
    return [] if title.blank?

    raw = raw.presence || ""
    search_data = Search.prepare_data(title.strip)

    return [] if search_data.blank?

    tsquery = Search.set_tsquery_weight_filter(search_data, "A")

    if raw.present?
      cooked =
        SearchIndexer::HtmlScrubber.scrub(PrettyText.cook(raw[0...MAX_SIMILAR_BODY_LENGTH].strip))

      prepared_data = cooked.present? && Search.prepare_data(cooked)

      if prepared_data.present?
        raw_tsquery = Search.set_tsquery_weight_filter(prepared_data, "B")

        tsquery = "#{tsquery} & #{raw_tsquery}"
      end
    end

    tsquery = Search.to_tsquery(term: tsquery, joiner: "|")

    guardian = Guardian.new(user)

    excluded_category_ids_sql =
      Category
        .secured(guardian)
        .where(search_priority: Searchable::PRIORITIES[:ignore])
        .select(:id)
        .to_sql

    excluded_category_ids_sql = <<~SQL if user
      #{excluded_category_ids_sql}
      UNION
      #{CategoryUser.muted_category_ids_query(user, include_direct: true).select("categories.id").to_sql}
      SQL

    candidates =
      Topic
        .visible
        .listable_topics
        .secured(guardian)
        .joins("JOIN topic_search_data s ON topics.id = s.topic_id")
        .joins("LEFT JOIN categories c ON topics.id = c.topic_id")
        .where("search_data @@ #{tsquery}")
        .where("c.topic_id IS NULL")
        .where("topics.category_id NOT IN (#{excluded_category_ids_sql})")
        .order("ts_rank(search_data, #{tsquery}) DESC")
        .limit(SiteSetting.max_similar_results * 3)

    candidate_ids = candidates.pluck(:id)

    return [] if candidate_ids.blank?

    similars =
      Topic
        .joins("JOIN posts AS p ON p.topic_id = topics.id AND p.post_number = 1")
        .where("topics.id IN (?)", candidate_ids)
        .order("similarity DESC")
        .limit(SiteSetting.max_similar_results)

    if raw.present?
      similars.select(
        DB.sql_fragment(
          "topics.*, similarity(topics.title, :title) + similarity(p.raw, :raw) AS similarity, p.cooked AS blurb",
          title: title,
          raw: raw,
        ),
      ).where(
        "similarity(topics.title, :title) + similarity(p.raw, :raw) > 0.2",
        title: title,
        raw: raw,
      )
    else
      similars.select(
        DB.sql_fragment(
          "topics.*, similarity(topics.title, :title) AS similarity, p.cooked AS blurb",
          title: title,
        ),
      ).where("similarity(topics.title, :title) > 0.2", title: title)
    end
  end

  def update_status(status, enabled, user, opts = {})
    TopicStatusUpdater.new(self, user).update!(status, enabled, opts)
    DiscourseEvent.trigger(:topic_status_updated, self, status, enabled)

    if status == "closed"
      StaffActionLogger.new(user).log_topic_closed(self, closed: enabled)
    elsif status == "archived"
      StaffActionLogger.new(user).log_topic_archived(self, archived: enabled)
    end

    if enabled && private_message? && status.to_s["closed"]
      group_ids = user.groups.pluck(:id)
      if group_ids.present?
        allowed_group_ids =
          self.allowed_groups.where("topic_allowed_groups.group_id IN (?)", group_ids).pluck(:id)
        allowed_group_ids.each { |id| GroupArchivedMessage.archive!(id, self) }
      end
    end
  end

  # Atomically creates the next post number
  def self.next_post_number(topic_id, opts = {})
    highest =
      DB
        .query_single(
          "SELECT coalesce(max(post_number),0) AS max FROM posts WHERE topic_id = ?",
          topic_id,
        )
        .first
        .to_i

    if opts[:whisper]
      result = DB.query_single(<<~SQL, highest, topic_id)
        UPDATE topics
        SET highest_staff_post_number = ? + 1
        WHERE id = ?
        RETURNING highest_staff_post_number
      SQL

      result.first.to_i
    else
      reply_sql = opts[:reply] ? ", reply_count = reply_count + 1" : ""
      posts_sql = opts[:post] ? ", posts_count = posts_count + 1" : ""

      result = DB.query_single(<<~SQL, highest: highest, topic_id: topic_id)
        UPDATE topics
        SET highest_staff_post_number = :highest + 1,
            highest_post_number = :highest + 1
            #{reply_sql}
            #{posts_sql}
        WHERE id = :topic_id
        RETURNING highest_post_number
      SQL

      result.first.to_i
    end
  end

  def self.reset_all_highest!
    DB.exec <<~SQL
      WITH
      X as (
        SELECT topic_id,
               COALESCE(MAX(post_number), 0) highest_post_number
        FROM posts
        WHERE deleted_at IS NULL
        GROUP BY topic_id
      ),
      Y as (
        SELECT topic_id,
               coalesce(MAX(post_number), 0) highest_post_number,
               count(*) posts_count,
               max(created_at) last_posted_at
        FROM posts
        WHERE deleted_at IS NULL AND post_type <> 4
        GROUP BY topic_id
      ),
      Z as (
        SELECT topic_id,
               SUM(COALESCE(posts.word_count, 0)) word_count
        FROM posts
        WHERE deleted_at IS NULL AND post_type <> 4
        GROUP BY topic_id
      )
      UPDATE topics
      SET
        highest_staff_post_number = X.highest_post_number,
        highest_post_number = Y.highest_post_number,
        last_posted_at = Y.last_posted_at,
        posts_count = Y.posts_count,
        word_count = Z.word_count
      FROM X, Y, Z
      WHERE
        topics.archetype <> 'private_message' AND
        X.topic_id = topics.id AND
        Y.topic_id = topics.id AND
        Z.topic_id = topics.id AND (
          topics.highest_staff_post_number <> X.highest_post_number OR
          topics.highest_post_number <> Y.highest_post_number OR
          topics.last_posted_at <> Y.last_posted_at OR
          topics.posts_count <> Y.posts_count OR
          topics.word_count <> Z.word_count
        )
    SQL

    DB.exec <<~SQL
      WITH
      X as (
        SELECT topic_id,
               COALESCE(MAX(post_number), 0) highest_post_number
        FROM posts
        WHERE deleted_at IS NULL
        GROUP BY topic_id
      ),
      Y as (
        SELECT topic_id,
               coalesce(MAX(post_number), 0) highest_post_number,
               count(*) posts_count,
               max(created_at) last_posted_at
        FROM posts
        WHERE deleted_at IS NULL AND post_type <> 3 AND post_type <> 4
        GROUP BY topic_id
      ),
      Z as (
        SELECT topic_id,
                SUM(COALESCE(posts.word_count, 0)) word_count
        FROM posts
        WHERE deleted_at IS NULL AND post_type <> 3 AND post_type <> 4
        GROUP BY topic_id
      )
      UPDATE topics
      SET
        highest_staff_post_number = X.highest_post_number,
        highest_post_number = Y.highest_post_number,
        last_posted_at = Y.last_posted_at,
        posts_count = Y.posts_count,
        word_count = Z.word_count
      FROM X, Y, Z
      WHERE
        topics.archetype = 'private_message' AND
        X.topic_id = topics.id AND
        Y.topic_id = topics.id AND
        Z.topic_id = topics.id AND (
          topics.highest_staff_post_number <> X.highest_post_number OR
          topics.highest_post_number <> Y.highest_post_number OR
          topics.last_posted_at <> Y.last_posted_at OR
          topics.posts_count <> Y.posts_count OR
          topics.word_count <> Z.word_count
        )
    SQL
  end

  # If a post is deleted we have to update our highest post counters and last post information
  def self.reset_highest(topic_id)
    archetype = Topic.where(id: topic_id).pick(:archetype)

    # ignore small_action replies for private messages
    post_type =
      archetype == Archetype.private_message ? " AND post_type <> #{Post.types[:small_action]}" : ""

    result = DB.query_single(<<~SQL, topic_id: topic_id)
      UPDATE topics
      SET
        highest_staff_post_number = (
          SELECT COALESCE(MAX(post_number), 0) FROM posts
          WHERE topic_id = :topic_id AND
                deleted_at IS NULL
        ),
        highest_post_number = (
          SELECT COALESCE(MAX(post_number), 0) FROM posts
          WHERE topic_id = :topic_id AND
                deleted_at IS NULL AND
                post_type <> 4
                #{post_type}
        ),
        posts_count = (
          SELECT count(*) FROM posts
          WHERE deleted_at IS NULL AND
                topic_id = :topic_id AND
                post_type <> 4
                #{post_type}
        ),
        word_count = (
          SELECT SUM(COALESCE(posts.word_count, 0)) FROM posts
          WHERE topic_id = :topic_id AND
                deleted_at IS NULL AND
                post_type <> 4
                #{post_type}
        ),
        last_posted_at = (
          SELECT MAX(created_at) FROM posts
          WHERE topic_id = :topic_id AND
                deleted_at IS NULL AND
                post_type <> 4
                #{post_type}
        ),
        last_post_user_id = COALESCE((
          SELECT user_id FROM posts
          WHERE topic_id = :topic_id AND
                deleted_at IS NULL AND
                post_type <> 4
                #{post_type}
          ORDER BY created_at desc
          LIMIT 1
        ), last_post_user_id)
      WHERE id = :topic_id
      RETURNING highest_post_number
    SQL

    highest_post_number = result.first.to_i

    # Update the forum topic user records
    DB.exec(<<~SQL, highest: highest_post_number, topic_id: topic_id)
      UPDATE topic_users
      SET last_read_post_number = CASE
                                  WHEN last_read_post_number > :highest THEN :highest
                                  ELSE last_read_post_number
                                  END
      WHERE topic_id = :topic_id
    SQL
  end

  cattr_accessor :update_featured_topics

  def changed_to_category(new_category)
    return true if new_category.blank? || Category.exists?(topic_id: id)

    if new_category.id == SiteSetting.uncategorized_category_id &&
         !SiteSetting.allow_uncategorized_topics
      return false
    end

    Topic.transaction do
      old_category = category

      if self.category_id != new_category.id
        self.update(category_id: new_category.id)

        if old_category
          Category.where(id: old_category.id).update_all("topic_count = topic_count - 1")

          count =
            if old_category.read_restricted && !new_category.read_restricted
              1
            elsif !old_category.read_restricted && new_category.read_restricted
              -1
            end

          Tag.update_counters(self.tags, { public_topic_count: count }) if count
        end

        # when a topic changes category we may have to start watching it
        # if we happen to have read state for it
        CategoryUser.auto_watch(category_id: new_category.id, topic_id: self.id)
        CategoryUser.auto_track(category_id: new_category.id, topic_id: self.id)

        if !SiteSetting.disable_category_edit_notifications && (post = self.ordered_posts.first)
          notified_user_ids = [post.user_id, post.last_editor_id].uniq
          DB.after_commit do
            Jobs.enqueue(
              :notify_category_change,
              post_id: post.id,
              notified_user_ids: notified_user_ids,
            )
          end
        end

        # when a topic changes category we may need to make uploads
        # linked to posts secure/not secure depending on whether the
        # category is private. this is only done if the category
        # has actually changed to avoid noise.
        DB.after_commit { Jobs.enqueue(:update_topic_upload_security, topic_id: self.id) }
      end

      Category.where(id: new_category.id).update_all("topic_count = topic_count + 1")

      if Topic.update_featured_topics != false
        CategoryFeaturedTopic.feature_topics_for(old_category) unless @import_mode
        unless @import_mode || old_category.try(:id) == new_category.id
          CategoryFeaturedTopic.feature_topics_for(new_category)
        end
      end
    end

    true
  end

  def add_small_action(user, action_code, who = nil, opts = {})
    custom_fields = {}
    custom_fields["action_code_who"] = who if who.present?
    opts =
      opts.merge(
        post_type: Post.types[:small_action],
        action_code: action_code,
        custom_fields: custom_fields,
      )

    add_moderator_post(user, nil, opts)
  end

  def add_moderator_post(user, text, opts = nil)
    opts ||= {}
    new_post = nil
    creator =
      PostCreator.new(
        user,
        raw: text,
        post_type: opts[:post_type] || Post.types[:moderator_action],
        action_code: opts[:action_code],
        no_bump: opts[:bump].blank?,
        topic_id: self.id,
        silent: opts[:silent],
        skip_validations: true,
        custom_fields: opts[:custom_fields],
        import_mode: opts[:import_mode],
      )

    if (new_post = creator.create) && new_post.present?
      increment!(:moderator_posts_count) if new_post.persisted?
      # If we are moving posts, we want to insert the moderator post where the previous posts were
      # in the stream, not at the end.
      if opts[:post_number].present?
        new_post.update!(post_number: opts[:post_number], sort_order: opts[:post_number])
      end

      # Grab any links that are present
      TopicLink.extract_from(new_post)
      QuotedPost.extract_from(new_post)
    end

    new_post
  end

  def change_category_to_id(category_id)
    return false if private_message?

    new_category_id = category_id.to_i
    # if the category name is blank, reset the attribute
    new_category_id = SiteSetting.uncategorized_category_id if new_category_id == 0

    return true if self.category_id == new_category_id

    cat = Category.find_by(id: new_category_id)
    return false unless cat

    reviewables.update_all(category_id: new_category_id)

    changed_to_category(cat)
  end

  def remove_allowed_group(removed_by, name)
    if group = Group.find_by(name: name)
      group_user = topic_allowed_groups.find_by(group_id: group.id)
      if group_user
        group_user.destroy
        allowed_groups.reload
        add_small_action(removed_by, "removed_group", group.name)
        return true
      end
    end

    false
  end

  def remove_allowed_user(removed_by, username)
    user = username.is_a?(User) ? username : User.find_by(username: username)

    if user
      topic_user = topic_allowed_users.find_by(user_id: user.id)

      if topic_user
        if user.id == removed_by&.id
          add_small_action(removed_by, "user_left", user.username)
        else
          add_small_action(removed_by, "removed_user", user.username)
        end

        topic_user.destroy
        return true
      end
    end

    false
  end

  def reached_recipients_limit?
    return false unless private_message?
    topic_allowed_users.count + topic_allowed_groups.count >=
      SiteSetting.max_allowed_message_recipients
  end

  def invite_group(user, group, should_notify: true)
    TopicAllowedGroup.create!(topic_id: self.id, group_id: group.id)
    self.allowed_groups.reload

    last_post =
      self.posts.order("post_number desc").where("not hidden AND posts.deleted_at IS NULL").first
    if last_post
      add_small_action(user, "invited_group", group.name)
      if should_notify
        Jobs.enqueue(:post_alert, post_id: last_post.id)
        Jobs.enqueue(:group_pm_alert, user_id: user.id, group_id: group.id, post_id: last_post.id)
      end
    end

    # If the group invited includes the OP of the topic as one of is members,
    # we cannot strip the topic_allowed_user record since it will be more
    # complicated to recover the topic_allowed_user record for the OP if the
    # group is removed.
    allowed_user_where_clause = <<~SQL
      users.id IN (
        SELECT topic_allowed_users.user_id
        FROM topic_allowed_users
        INNER JOIN group_users ON group_users.user_id = topic_allowed_users.user_id
        INNER JOIN topic_allowed_groups ON topic_allowed_groups.group_id = group_users.group_id
        WHERE topic_allowed_groups.group_id = :group_id AND
              topic_allowed_users.topic_id = :topic_id AND
              topic_allowed_users.user_id != :op_user_id
      )
    SQL
    User
      .where(
        [
          allowed_user_where_clause,
          { group_id: group.id, topic_id: self.id, op_user_id: self.user_id },
        ],
      )
      .find_each { |allowed_user| remove_allowed_user(Discourse.system_user, allowed_user) }

    true
  end

  def invite(invited_by, username_or_email, group_ids = nil, custom_message = nil)
    guardian = Guardian.new(invited_by)

    if target_user = User.find_by_username_or_email(username_or_email)
      if topic_allowed_users.exists?(user_id: target_user.id)
        raise UserExists.new(I18n.t("topic_invite.user_exists"))
      end

      comm_screener = UserCommScreener.new(acting_user: invited_by, target_user_ids: target_user.id)
      if comm_screener.ignoring_or_muting_actor?(target_user.id)
        raise NotAllowed.new(I18n.t("not_accepting_pms", username: target_user.username))
      end

      if TopicUser.where(
           topic: self,
           user: target_user,
           notification_level: TopicUser.notification_levels[:muted],
         ).exists?
        raise NotAllowed.new(I18n.t("topic_invite.muted_topic"))
      end

      if comm_screener.disallowing_pms_from_actor?(target_user.id)
        raise NotAllowed.new(I18n.t("topic_invite.receiver_does_not_allow_pm"))
      end

      if UserCommScreener.new(
           acting_user: target_user,
           target_user_ids: invited_by.id,
         ).disallowing_pms_from_actor?(invited_by.id)
        raise NotAllowed.new(I18n.t("topic_invite.sender_does_not_allow_pm"))
      end

      if private_message?
        !!invite_to_private_message(invited_by, target_user, guardian)
      else
        !!invite_to_topic(invited_by, target_user, group_ids, guardian)
      end
    elsif username_or_email =~ /\A.+@.+\z/ && guardian.can_invite_via_email?(self)
      !!Invite.generate(
        invited_by,
        email: username_or_email,
        topic: self,
        group_ids: group_ids,
        custom_message: custom_message,
        invite_to_topic: true,
      )
    end
  end

  def email_already_exists_for?(invite)
    invite.email_already_exists && private_message?
  end

  def grant_permission_to_user(lower_email)
    user = User.find_by_email(lower_email)
    unless topic_allowed_users.exists?(user_id: user.id)
      topic_allowed_users.create!(user_id: user.id)
    end
  end

  def max_post_number
    posts.with_deleted.maximum(:post_number).to_i
  end

  def move_posts(moved_by, post_ids, opts)
    post_mover =
      PostMover.new(
        self,
        moved_by,
        post_ids,
        move_to_pm: opts[:archetype].present? && opts[:archetype] == "private_message",
      )

    if opts[:destination_topic_id]
      topic =
        post_mover.to_topic(
          opts[:destination_topic_id],
          **opts.slice(:participants, :chronological_order),
        )

      DiscourseEvent.trigger(:topic_merged, post_mover.original_topic, post_mover.destination_topic)

      topic
    elsif opts[:title]
      post_mover.to_new_topic(opts[:title], opts[:category_id], opts[:tags])
    end
  end

  # Updates the denormalized statistics of a topic including featured posters. They shouldn't
  # go out of sync unless you do something drastic live move posts from one topic to another.
  # this recalculates everything.
  def update_statistics
    feature_topic_users
    update_action_counts
    Topic.reset_highest(id)
  end

  def update_action_counts
    update_column(
      :like_count,
      Post.where.not(post_type: Post.types[:whisper]).where(topic_id: id).sum(:like_count),
    )
  end

  def posters_summary(options = {}) # avatar lookup in options
    @posters_summary ||= TopicPostersSummary.new(self, options).summary
  end

  def participants_summary(options = {})
    @participants_summary ||= TopicParticipantsSummary.new(self, options).summary
  end

  def participant_groups_summary(options = {})
    @participant_groups_summary ||= TopicParticipantGroupsSummary.new(self, options).summary
  end

  def make_banner!(user, bannered_until = nil)
    if bannered_until
      bannered_until =
        begin
          Time.parse(bannered_until)
        rescue ArgumentError
          raise Discourse::InvalidParameters.new(:bannered_until)
        end
    end

    # only one banner at the same time
    previous_banner = Topic.where(archetype: Archetype.banner).first
    previous_banner.remove_banner!(user) if previous_banner.present?

    UserProfile.where("dismissed_banner_key IS NOT NULL").update_all(dismissed_banner_key: nil)

    self.archetype = Archetype.banner
    self.bannered_until = bannered_until
    self.add_small_action(user, "banner.enabled")
    self.save

    MessageBus.publish("/site/banner", banner)

    Jobs.cancel_scheduled_job(:remove_banner, topic_id: self.id)
    Jobs.enqueue_at(bannered_until, :remove_banner, topic_id: self.id) if bannered_until
  end

  def remove_banner!(user)
    self.archetype = Archetype.default
    self.bannered_until = nil
    self.add_small_action(user, "banner.disabled")
    self.save

    MessageBus.publish("/site/banner", nil)

    Jobs.cancel_scheduled_job(:remove_banner, topic_id: self.id)
  end

  def banner
    post = self.ordered_posts.first

    { html: post.cooked, key: self.id, url: self.url }
  end

  cattr_accessor :slug_computed_callbacks
  self.slug_computed_callbacks = []

  def slug_for_topic(title)
    return "" if title.blank?
    slug = Slug.for(title)

    # this is a hook for plugins that need to modify the generated slug
    self.class.slug_computed_callbacks.each { |callback| slug = callback.call(self, slug, title) }

    slug
  end

  # Even if the slug column in the database is null, topic.slug will return something:
  def slug
    unless slug = read_attribute(:slug)
      return "" if title.blank?
      slug = slug_for_topic(title)
      if new_record?
        write_attribute(:slug, slug)
      else
        update_column(:slug, slug)
      end
    end

    slug
  end

  def self.find_by_slug(slug)
    if SiteSetting.slug_generation_method != "encoded"
      Topic.find_by(slug: slug.downcase)
    else
      encoded_slug = CGI.escape(slug)
      Topic.find_by(slug: encoded_slug)
    end
  end

  def title=(t)
    slug = slug_for_topic(t.to_s)
    write_attribute(:slug, slug)
    write_attribute(:fancy_title, nil)
    write_attribute(:title, t)
  end

  # NOTE: These are probably better off somewhere else.
  #       Having a model know about URLs seems a bit strange.
  def last_post_url
    "#{Discourse.base_path}/t/#{slug}/#{id}/#{posts_count}"
  end

  def self.url(id, slug, post_number = nil)
    url = +"#{Discourse.base_url}/t/#{slug}/#{id}"
    url << "/#{post_number}" if post_number.to_i > 1
    url
  end

  def url(post_number = nil)
    self.class.url id, slug, post_number
  end

  def self.relative_url(id, slug, post_number = nil)
    url = +"#{Discourse.base_path}/t/"
    url << "#{slug}/" if slug.present?
    url << id.to_s
    url << "/#{post_number}" if post_number.to_i > 1
    url
  end

  def slugless_url(post_number = nil)
    Topic.relative_url(id, nil, post_number)
  end

  def relative_url(post_number = nil)
    Topic.relative_url(id, slug, post_number)
  end

  def clear_pin_for(user)
    return if user.blank?
    TopicUser.change(user.id, id, cleared_pinned_at: Time.now)
  end

  def re_pin_for(user)
    return if user.blank?
    TopicUser.change(user.id, id, cleared_pinned_at: nil)
  end

  def update_pinned(status, global = false, pinned_until = nil)
    if pinned_until
      pinned_until =
        begin
          Time.parse(pinned_until)
        rescue ArgumentError
          raise Discourse::InvalidParameters.new(:pinned_until)
        end
    end

    update_columns(
      pinned_at: status ? Time.zone.now : nil,
      pinned_globally: global,
      pinned_until: pinned_until,
    )

    Jobs.cancel_scheduled_job(:unpin_topic, topic_id: self.id)
    Jobs.enqueue_at(pinned_until, :unpin_topic, topic_id: self.id) if pinned_until
  end

  def draft_key
    "#{Draft::EXISTING_TOPIC}#{id}"
  end

  def notifier
    @topic_notifier ||= TopicNotifier.new(self)
  end

  def muted?(user)
    notifier.muted?(user.id) if user && user.id
  end

  def self.ensure_consistency!
    # unpin topics that might have been missed
    Topic.where("pinned_until < ?", Time.now).update_all(
      pinned_at: nil,
      pinned_globally: false,
      pinned_until: nil,
    )
    Topic
      .where("bannered_until < ?", Time.now)
      .find_each { |topic| topic.remove_banner!(Discourse.system_user) }
  end

  def inherit_slow_mode_from_category
    if self.category&.default_slow_mode_seconds
      self.slow_mode_seconds = self.category&.default_slow_mode_seconds
    end
  end

  def inherit_auto_close_from_category(timer_type: :close)
    auto_close_hours = self.category&.auto_close_hours

    if self.open? && !@ignore_category_auto_close && auto_close_hours.present? &&
         public_topic_timer&.execute_at.blank?
      based_on_last_post = self.category.auto_close_based_on_last_post
      duration_minutes = based_on_last_post ? auto_close_hours * 60 : nil

      # the timer time can be a timestamp or an integer based
      # on the number of hours
      auto_close_time = auto_close_hours

      if !based_on_last_post
        # set auto close to the original time it should have been
        # when the topic was first created.
        start_time = self.created_at || Time.zone.now
        auto_close_time = start_time + auto_close_hours.hours

        # if we have already passed the original close time then
        # we should not recreate the auto-close timer for the topic
        return if auto_close_time < Time.zone.now

        # timestamp must be a string for set_or_create_timer
        auto_close_time = auto_close_time.to_s
      end

      self.set_or_create_timer(
        TopicTimer.types[timer_type],
        auto_close_time,
        by_user: Discourse.system_user,
        based_on_last_post: based_on_last_post,
        duration_minutes: duration_minutes,
      )
    end
  end

  def public_topic_timer
    @public_topic_timer ||= topic_timers.find_by(public_type: true)
  end

  def slow_mode_topic_timer
    @slow_mode_topic_timer ||= topic_timers.find_by(status_type: TopicTimer.types[:clear_slow_mode])
  end

  def delete_topic_timer(status_type, by_user: Discourse.system_user)
    options = { status_type: status_type }
    options.merge!(user: by_user) unless TopicTimer.public_types[status_type]
    self.topic_timers.find_by(options)&.trash!(by_user)
    @public_topic_timer = nil
    nil
  end

  # Valid arguments for the time:
  #  * An integer, which is the number of hours from now to update the topic's status.
  #  * A timestamp, like "2013-11-25 13:00", when the topic's status should update.
  #  * A timestamp with timezone in JSON format. (e.g., "2013-11-26T21:00:00.000Z")
  #  * `nil` to delete the topic's status update.
  # Options:
  #  * by_user: User who is setting the topic's status update.
  #  * based_on_last_post: True if time should be based on timestamp of the last post.
  #  * category_id: Category that the update will apply to.
  #  * duration_minutes: The duration of the timer in minutes, which is used if the timer is based
  #                      on the last post or if the timer type is delete_replies.
  #  * silent: Affects whether the close topic timer status change will be silent or not.
  def set_or_create_timer(
    status_type,
    time,
    by_user: nil,
    based_on_last_post: false,
    category_id: SiteSetting.uncategorized_category_id,
    duration_minutes: nil,
    silent: nil
  )
    if time.blank? && duration_minutes.blank?
      return delete_topic_timer(status_type, by_user: by_user)
    end

    duration_minutes = duration_minutes ? duration_minutes.to_i : 0
    public_topic_timer = !!TopicTimer.public_types[status_type]
    topic_timer_options = { topic: self, public_type: public_topic_timer }
    topic_timer_options.merge!(user: by_user) unless public_topic_timer
    topic_timer_options.merge!(silent: silent) if silent
    topic_timer = TopicTimer.find_or_initialize_by(topic_timer_options)
    topic_timer.status_type = status_type

    time_now = Time.zone.now
    topic_timer.based_on_last_post = !based_on_last_post.blank?

    if status_type == TopicTimer.types[:publish_to_category]
      topic_timer.category = Category.find_by(id: category_id)
    end

    if topic_timer.based_on_last_post
      if duration_minutes > 0
        last_post_created_at =
          self.ordered_posts.last.present? ? self.ordered_posts.last.created_at : time_now
        topic_timer.duration_minutes = duration_minutes
        topic_timer.execute_at = last_post_created_at + duration_minutes.minutes
        topic_timer.created_at = last_post_created_at
      end
    elsif topic_timer.status_type == TopicTimer.types[:delete_replies]
      if duration_minutes > 0
        first_reply_created_at =
          (self.ordered_posts.where("post_number > 1").minimum(:created_at) || time_now)
        topic_timer.duration_minutes = duration_minutes
        topic_timer.execute_at = first_reply_created_at + duration_minutes.minutes
        topic_timer.created_at = first_reply_created_at
      end
    else
      utc = Time.find_zone("UTC")
      is_float =
        (
          begin
            Float(time)
          rescue StandardError
            nil
          end
        )

      if is_float
        num_hours = time.to_f
        topic_timer.execute_at = num_hours.hours.from_now if num_hours > 0
      else
        timestamp = utc.parse(time)
        raise Discourse::InvalidParameters unless timestamp && timestamp > utc.now
        # a timestamp in client's time zone, like "2015-5-27 12:00"
        topic_timer.execute_at = timestamp
      end
    end

    if topic_timer.execute_at
      if by_user&.staff? || by_user&.trust_level == TrustLevel[4]
        topic_timer.user = by_user
      else
        topic_timer.user ||=
          (
            if self.user.staff? || self.user.trust_level == TrustLevel[4]
              self.user
            else
              Discourse.system_user
            end
          )
      end

      if self.persisted?
        # See TopicTimer.after_save for additional context; the topic
        # status may be changed by saving.
        topic_timer.save!
      else
        self.topic_timers << topic_timer
      end

      topic_timer
    end
  end

  def read_restricted_category?
    category && category.read_restricted
  end

  def category_allows_unlimited_owner_edits_on_first_post?
    category && category.allow_unlimited_owner_edits_on_first_post?
  end

  def acting_user
    @acting_user || user
  end

  def acting_user=(u)
    @acting_user = u
  end

  def secure_group_ids
    @secure_group_ids ||=
      (self.category.secure_group_ids if self.category && self.category.read_restricted?)
  end

  def has_topic_embed?
    TopicEmbed.where(topic_id: id).exists?
  end

  def expandable_first_post?
    SiteSetting.embed_truncate? && has_topic_embed?
  end

  def message_archived?(user)
    return false unless user && user.id

    # tricky query but this checks to see if message is archived for ALL groups you belong to
    # OR if you have it archived as a user explicitly

    sql = <<~SQL
      SELECT 1
      WHERE
        (
        SELECT count(*) FROM topic_allowed_groups tg
        JOIN group_archived_messages gm
              ON gm.topic_id = tg.topic_id AND
                 gm.group_id = tg.group_id
          WHERE tg.group_id IN (SELECT g.group_id FROM group_users g WHERE g.user_id = :user_id)
            AND tg.topic_id = :topic_id
        ) =
        (
          SELECT case when count(*) = 0 then -1 else count(*) end FROM topic_allowed_groups tg
          WHERE tg.group_id IN (SELECT g.group_id FROM group_users g WHERE g.user_id = :user_id)
            AND tg.topic_id = :topic_id
        )

        UNION ALL

        SELECT 1 FROM topic_allowed_users tu
        JOIN user_archived_messages um ON um.user_id = tu.user_id AND um.topic_id = tu.topic_id
        WHERE tu.user_id = :user_id AND tu.topic_id = :topic_id
    SQL

    DB.exec(sql, user_id: user.id, topic_id: id) > 0
  end

  TIME_TO_FIRST_RESPONSE_SQL = <<-SQL
    SELECT AVG(t.hours)::float AS "hours", t.created_at AS "date"
    FROM (
      SELECT t.id, t.created_at::date AS created_at, EXTRACT(EPOCH FROM MIN(p.created_at) - t.created_at)::float / 3600.0 AS "hours"
      FROM topics t
      LEFT JOIN posts p ON p.topic_id = t.id
      /*where*/
      GROUP BY t.id
    ) t
    GROUP BY t.created_at
    ORDER BY t.created_at
  SQL

  TIME_TO_FIRST_RESPONSE_TOTAL_SQL = <<-SQL
    SELECT AVG(t.hours)::float AS "hours"
    FROM (
      SELECT t.id, EXTRACT(EPOCH FROM MIN(p.created_at) - t.created_at)::float / 3600.0 AS "hours"
      FROM topics t
      LEFT JOIN posts p ON p.topic_id = t.id
      /*where*/
      GROUP BY t.id
    ) t
  SQL

  def self.time_to_first_response(sql, opts = nil)
    opts ||= {}
    builder = DB.build(sql)
    builder.where("t.created_at >= :start_date", start_date: opts[:start_date]) if opts[:start_date]
    builder.where("t.created_at < :end_date", end_date: opts[:end_date]) if opts[:end_date]
    if opts[:category_id]
      if opts[:include_subcategories]
        builder.where("t.category_id IN (?)", Category.subcategory_ids(opts[:category_id]))
      else
        builder.where("t.category_id = ?", opts[:category_id])
      end
    end
    builder.where("t.archetype <> '#{Archetype.private_message}'")
    builder.where("t.deleted_at IS NULL")
    builder.where("p.deleted_at IS NULL")
    builder.where("p.post_number > 1")
    builder.where("p.user_id != t.user_id")
    builder.where("p.user_id in (:user_ids)", user_ids: opts[:user_ids]) if opts[:user_ids]
    builder.where("p.post_type = :post_type", post_type: Post.types[:regular])
    builder.where("EXTRACT(EPOCH FROM p.created_at - t.created_at) > 0")
    builder.query_hash
  end

  def self.time_to_first_response_per_day(start_date, end_date, opts = {})
    time_to_first_response(
      TIME_TO_FIRST_RESPONSE_SQL,
      opts.merge(start_date: start_date, end_date: end_date),
    )
  end

  def self.time_to_first_response_total(opts = nil)
    total = time_to_first_response(TIME_TO_FIRST_RESPONSE_TOTAL_SQL, opts)
    total.first["hours"].to_f.round(2)
  end

  WITH_NO_RESPONSE_SQL = <<-SQL
    SELECT COUNT(*) as count, tt.created_at AS "date"
    FROM (
      SELECT t.id, t.created_at::date AS created_at, MIN(p.post_number) first_reply
      FROM topics t
      LEFT JOIN posts p ON p.topic_id = t.id AND p.user_id != t.user_id AND p.deleted_at IS NULL AND p.post_type = #{Post.types[:regular]}
      /*where*/
      GROUP BY t.id
    ) tt
    WHERE tt.first_reply IS NULL OR tt.first_reply < 2
    GROUP BY tt.created_at
    ORDER BY tt.created_at
  SQL

  def self.with_no_response_per_day(
    start_date,
    end_date,
    category_id = nil,
    include_subcategories = nil
  )
    builder = DB.build(WITH_NO_RESPONSE_SQL)
    builder.where("t.created_at >= :start_date", start_date: start_date) if start_date
    builder.where("t.created_at < :end_date", end_date: end_date) if end_date
    if category_id
      if include_subcategories
        builder.where("t.category_id IN (?)", Category.subcategory_ids(category_id))
      else
        builder.where("t.category_id = ?", category_id)
      end
    end
    builder.where("t.archetype <> '#{Archetype.private_message}'")
    builder.where("t.deleted_at IS NULL")
    builder.query_hash
  end

  WITH_NO_RESPONSE_TOTAL_SQL = <<-SQL
    SELECT COUNT(*) as count
    FROM (
      SELECT t.id, MIN(p.post_number) first_reply
      FROM topics t
      LEFT JOIN posts p ON p.topic_id = t.id AND p.user_id != t.user_id AND p.deleted_at IS NULL AND p.post_type = #{Post.types[:regular]}
      /*where*/
      GROUP BY t.id
    ) tt
    WHERE tt.first_reply IS NULL OR tt.first_reply < 2
  SQL

  def self.with_no_response_total(opts = {})
    builder = DB.build(WITH_NO_RESPONSE_TOTAL_SQL)
    if opts[:category_id]
      if opts[:include_subcategories]
        builder.where("t.category_id IN (?)", Category.subcategory_ids(opts[:category_id]))
      else
        builder.where("t.category_id = ?", opts[:category_id])
      end
    end
    builder.where("t.archetype <> '#{Archetype.private_message}'")
    builder.where("t.deleted_at IS NULL")
    builder.query_single.first.to_i
  end

  def convert_to_public_topic(user, category_id: nil)
    TopicConverter.new(self, user).convert_to_public_topic(category_id)
  end

  def convert_to_private_message(user)
    TopicConverter.new(self, user).convert_to_private_message
  end

  def update_excerpt(excerpt)
    update_column(:excerpt, excerpt)
    ApplicationController.banner_json_cache.clear if archetype == "banner"
  end

  def pm_with_non_human_user?
    sql = <<~SQL
    SELECT 1 FROM topics
    LEFT JOIN topic_allowed_groups ON topics.id = topic_allowed_groups.topic_id
    WHERE topic_allowed_groups.topic_id IS NULL
    AND topics.archetype = :private_message
    AND topics.id = :topic_id
    AND (
      SELECT COUNT(*) FROM topic_allowed_users
      WHERE topic_allowed_users.topic_id = :topic_id
      AND topic_allowed_users.user_id > 0
    ) = 1
    SQL

    result = DB.exec(sql, private_message: Archetype.private_message, topic_id: self.id)
    result != 0
  end

  def featured_link_root_domain
    MiniSuffix.domain(UrlHelper.encode_and_parse(self.featured_link).hostname)
  end

  def self.private_message_topics_count_per_day(start_date, end_date, topic_subtype)
    private_messages
      .with_subtype(topic_subtype)
      .where("topics.created_at >= ? AND topics.created_at <= ?", start_date, end_date)
      .group("date(topics.created_at)")
      .order("date(topics.created_at)")
      .count
  end

  def is_category_topic?
    @is_category_topic ||= Category.exists?(topic_id: self.id.to_i)
  end

  def reset_bumped_at(post_id = nil)
    post =
      (
        if post_id
          Post.find_by(id: post_id)
        else
          ordered_posts.where(
            user_deleted: false,
            hidden: false,
            post_type: Post.types[:regular],
          ).last || first_post
        end
      )

    return if !post

    self.bumped_at = post.created_at
    self.save(validate: false)
  end

  def auto_close_threshold_reached?
    return if user&.staff?

    scores =
      ReviewableScore
        .pending
        .joins(:reviewable)
        .where("reviewable_scores.score >= ?", Reviewable.min_score_for_priority)
        .where("reviewables.topic_id = ?", self.id)
        .pluck(
          "COUNT(DISTINCT reviewable_scores.user_id), COALESCE(SUM(reviewable_scores.score), 0.0)",
        )
        .first

    scores[0] >= SiteSetting.num_flaggers_to_close_topic &&
      scores[1] >= Reviewable.score_to_auto_close_topic
  end

  def update_category_topic_count_by(num)
    if category_id.present?
      Category
        .where("id = ?", category_id)
        .where("topic_id != ? OR topic_id IS NULL", self.id)
        .update_all("topic_count = topic_count + #{num.to_i}")
    end
  end

  def access_topic_via_group
    Group
      .joins(:category_groups)
      .where("category_groups.category_id = ?", self.category_id)
      .where("groups.public_admission OR groups.allow_membership_requests")
      .order(:allow_membership_requests)
      .first
  end

  def incoming_email_addresses(group: nil, received_before: Time.zone.now)
    email_addresses = Set.new

    self
      .incoming_email
      .where("created_at <= ?", received_before)
      .each do |incoming_email|
        to_addresses = incoming_email.to_addresses_split
        cc_addresses = incoming_email.cc_addresses_split
        combined_addresses = [to_addresses, cc_addresses].flatten

        # We only care about the emails addressed to the group or CC'd to the
        # group if the group is present. If combined addresses is empty we do
        # not need to do this check, and instead can proceed on to adding the
        # from address.
        #
        # Will not include test1@gmail.com if the only IncomingEmail
        # is:
        #
        # from: test1@gmail.com
        # to: test+support@discoursemail.com
        #
        # Because we don't care about the from addresses and also the to address
        # is not the email_username, which will be something like test1@gmail.com.
        if group.present? && combined_addresses.any?
          next if combined_addresses.none? { |address| address =~ group.email_username_regex }
        end

        email_addresses.add(incoming_email.from_address)
        email_addresses.merge(combined_addresses)
      end

    email_addresses.subtract([nil, ""])
    email_addresses.delete(group.email_username) if group.present?

    email_addresses.to_a
  end

  def create_invite_notification!(target_user, notification_type, invited_by, post_number: 1)
    if UserCommScreener.new(
         acting_user: invited_by,
         target_user_ids: target_user.id,
       ).ignoring_or_muting_actor?(target_user.id)
      raise NotAllowed.new(I18n.t("not_accepting_pms", username: target_user.username))
    end

    target_user.notifications.create!(
      notification_type: notification_type,
      topic_id: self.id,
      post_number: post_number,
      data: {
        topic_title: self.title,
        display_username: invited_by.username,
        original_user_id: user.id,
        original_username: user.username,
      }.to_json,
    )
  end

  def rate_limit_topic_invitation(invited_by)
    RateLimiter.new(
      invited_by,
      "topic-invitations-per-day",
      SiteSetting.max_topic_invitations_per_day,
      1.day.to_i,
    ).performed!

    RateLimiter.new(
      invited_by,
      "topic-invitations-per-minute",
      SiteSetting.max_topic_invitations_per_minute,
      1.day.to_i,
    ).performed!
  end

  def cannot_permanently_delete_reason(user)
    all_posts_count =
      Post
        .with_deleted
        .where(topic_id: self.id)
        .where(
          post_type: [Post.types[:regular], Post.types[:moderator_action], Post.types[:whisper]],
        )
        .count

    if posts_count > 0 || all_posts_count > 1
      I18n.t("post.cannot_permanently_delete.many_posts")
    elsif self.deleted_by_id == user&.id && self.deleted_at >= Post::PERMANENT_DELETE_TIMER.ago
      time_left =
        RateLimiter.time_left(
          Post::PERMANENT_DELETE_TIMER.to_i - Time.zone.now.to_i + self.deleted_at.to_i,
        )
      I18n.t("post.cannot_permanently_delete.wait_or_different_admin", time_left: time_left)
    end
  end

  def first_smtp_enabled_group
    self.allowed_groups.where(smtp_enabled: true).first
  end

  def secure_audience_publish_messages
    target_audience = {}

    if private_message?
      target_audience[:user_ids] = User.human_users.where("admin OR moderator").pluck(:id)
      target_audience[:user_ids] |= allowed_users.pluck(:id)
      target_audience[:user_ids] |= allowed_group_users.pluck(:id)
    else
      target_audience[:group_ids] = secure_group_ids
    end

    target_audience
  end

  def self.publish_stats_to_clients!(topic_id, type, opts = {})
    topic = Topic.find_by(id: topic_id)
    return if topic.blank?

    case type
    when :liked, :unliked
      stats = { like_count: topic.like_count }
    when :created, :destroyed, :deleted, :recovered
      stats = {
        posts_count: topic.posts_count,
        last_posted_at: topic.last_posted_at.as_json,
        last_poster: BasicUserSerializer.new(topic.last_poster, root: false).as_json,
      }
    else
      stats = nil
    end

    if stats
      secure_audience = topic.secure_audience_publish_messages

      if secure_audience[:user_ids] != [] && secure_audience[:group_ids] != []
        message = stats.merge({ id: topic_id, updated_at: Time.now, type: :stats })
        MessageBus.publish("/topic/#{topic_id}", message, opts.merge(secure_audience))
      end
    end
  end

  def group_pm?
    private_message? && all_allowed_users.count > 2
  end

  def visible_tags(guardian)
    tags.reject { |tag| guardian.hidden_tag_names.include?(tag[:name]) }
  end

  def self.editable_custom_fields(guardian)
    fields = []
    fields.push(*DiscoursePluginRegistry.public_editable_topic_custom_fields)
    fields.push(*DiscoursePluginRegistry.staff_editable_topic_custom_fields) if guardian.is_staff?
    fields
  end

  private

  def invite_to_private_message(invited_by, target_user, guardian)
    if !guardian.can_send_private_message?(target_user)
      raise UserExists.new(I18n.t("activerecord.errors.models.topic.attributes.base.cant_send_pm"))
    end

    rate_limit_topic_invitation(invited_by)

    Topic.transaction do
      unless topic_allowed_users.exists?(user_id: target_user.id)
        topic_allowed_users.create!(user_id: target_user.id)
      end

      user_in_allowed_group = (user.group_ids & topic_allowed_groups.map(&:group_id)).present?
      add_small_action(invited_by, "invited_user", target_user.username) if !user_in_allowed_group

      create_invite_notification!(
        target_user,
        Notification.types[:invited_to_private_message],
        invited_by,
      )
    end
  end

  def invite_to_topic(invited_by, target_user, group_ids, guardian)
    Topic.transaction do
      rate_limit_topic_invitation(invited_by)

      if group_ids.present?
        (
          self.category.groups.where(id: group_ids).where(automatic: false) -
            target_user.groups.where(automatic: false)
        ).each do |group|
          if guardian.can_edit_group?(group)
            group.add(target_user)

            GroupActionLogger.new(invited_by, group).log_add_user_to_group(target_user)
          end
        end
      end

      if Guardian.new(target_user).can_see_topic?(self)
        create_invite_notification!(target_user, Notification.types[:invited_to_topic], invited_by)
      end
    end
  end

  def limit_first_day_topics_per_day
    apply_per_day_rate_limit_for("first-day-topics", :max_topics_in_first_day)
  end

  def apply_per_day_rate_limit_for(key, method_name)
    RateLimiter.new(user, "#{key}-per-day", SiteSetting.get(method_name), 1.day.to_i)
  end
end

# == Schema Information
#
# Table name: topics
#
#  id                        :integer          not null, primary key
#  title                     :string           not null
#  last_posted_at            :datetime
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  views                     :integer          default(0), not null
#  posts_count               :integer          default(0), not null
#  user_id                   :integer
#  last_post_user_id         :integer          not null
#  reply_count               :integer          default(0), not null
#  featured_user1_id         :integer
#  featured_user2_id         :integer
#  featured_user3_id         :integer
#  deleted_at                :datetime
#  highest_post_number       :integer          default(0), not null
#  like_count                :integer          default(0), not null
#  incoming_link_count       :integer          default(0), not null
#  category_id               :integer
#  visible                   :boolean          default(TRUE), not null
#  moderator_posts_count     :integer          default(0), not null
#  closed                    :boolean          default(FALSE), not null
#  archived                  :boolean          default(FALSE), not null
#  bumped_at                 :datetime         not null
#  has_summary               :boolean          default(FALSE), not null
#  archetype                 :string           default("regular"), not null
#  featured_user4_id         :integer
#  notify_moderators_count   :integer          default(0), not null
#  spam_count                :integer          default(0), not null
#  pinned_at                 :datetime
#  score                     :float
#  percent_rank              :float            default(1.0), not null
#  subtype                   :string
#  slug                      :string
#  deleted_by_id             :integer
#  participant_count         :integer          default(1)
#  word_count                :integer
#  excerpt                   :string
#  pinned_globally           :boolean          default(FALSE), not null
#  pinned_until              :datetime
#  fancy_title               :string
#  highest_staff_post_number :integer          default(0), not null
#  featured_link             :string
#  reviewable_score          :float            default(0.0), not null
#  image_upload_id           :bigint
#  slow_mode_seconds         :integer          default(0), not null
#  bannered_until            :datetime
#  external_id               :string
#  visibility_reason_id      :integer
#
# Indexes
#
#  idx_topics_front_page                   (deleted_at,visible,archetype,category_id,id)
#  idx_topics_user_id_deleted_at           (user_id) WHERE (deleted_at IS NULL)
#  idxtopicslug                            (slug) WHERE ((deleted_at IS NULL) AND (slug IS NOT NULL))
#  index_topics_on_bannered_until          (bannered_until) WHERE (bannered_until IS NOT NULL)
#  index_topics_on_bumped_at_public        (bumped_at) WHERE ((deleted_at IS NULL) AND ((archetype)::text <> 'private_message'::text))
#  index_topics_on_created_at_and_visible  (created_at,visible) WHERE ((deleted_at IS NULL) AND ((archetype)::text <> 'private_message'::text))
#  index_topics_on_external_id             (external_id) UNIQUE WHERE (external_id IS NOT NULL)
#  index_topics_on_id_and_deleted_at       (id,deleted_at)
#  index_topics_on_id_filtered_banner      (id) UNIQUE WHERE (((archetype)::text = 'banner'::text) AND (deleted_at IS NULL))
#  index_topics_on_image_upload_id         (image_upload_id)
#  index_topics_on_lower_title             (lower((title)::text))
#  index_topics_on_pinned_at               (pinned_at) WHERE (pinned_at IS NOT NULL)
#  index_topics_on_pinned_globally         (pinned_globally) WHERE pinned_globally
#  index_topics_on_pinned_until            (pinned_until) WHERE (pinned_until IS NOT NULL)
#  index_topics_on_timestamps_private      (bumped_at,created_at,updated_at) WHERE ((deleted_at IS NULL) AND ((archetype)::text = 'private_message'::text))
#  index_topics_on_updated_at_public       (updated_at,visible,highest_staff_post_number,highest_post_number,category_id,created_at,id) WHERE (((archetype)::text <> 'private_message'::text) AND (deleted_at IS NULL))
#
