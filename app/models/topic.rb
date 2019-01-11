require_dependency 'slug'
require_dependency 'avatar_lookup'
require_dependency 'topic_view'
require_dependency 'rate_limiter'
require_dependency 'text_sentinel'
require_dependency 'text_cleaner'
require_dependency 'archetype'
require_dependency 'html_prettify'
require_dependency 'discourse_tagging'
require_dependency 'search_indexer'
require_dependency 'list_controller'
require_dependency 'topic_posters_summary'
require_dependency 'topic_featured_users'

class Topic < ActiveRecord::Base
  # TODO remove 01-01-2019
  self.ignored_columns = ["percent_rank", "vote_count"]

  class UserExists < StandardError; end
  include ActionView::Helpers::SanitizeHelper
  include RateLimiter::OnCreateRecord
  include HasCustomFields
  include Trashable
  include Searchable
  include LimitedEdit
  extend Forwardable

  def_delegator :featured_users, :user_ids, :featured_user_ids
  def_delegator :featured_users, :choose, :feature_topic_users

  def_delegator :notifier, :watch!, :notify_watch!
  def_delegator :notifier, :track!, :notify_tracking!
  def_delegator :notifier, :regular!, :notify_regular!
  def_delegator :notifier, :mute!, :notify_muted!
  def_delegator :notifier, :toggle_mute, :toggle_mute

  attr_accessor :allowed_user_ids, :tags_changed, :includes_destination_category

  DiscourseEvent.on(:site_setting_saved) do |site_setting|
    if site_setting.name.to_s == "slug_generation_method" && site_setting.saved_change_to_value?
      Scheduler::Defer.later("Null topic slug") do
        Topic.update_all(slug: nil)
      end
    end
  end

  def self.max_fancy_title_length
    400
  end

  def featured_users
    @featured_users ||= TopicFeaturedUsers.new(self)
  end

  def trash!(trashed_by = nil)
    if deleted_at.nil?
      update_category_topic_count_by(-1)
      CategoryTagStat.topic_deleted(self) if self.tags.present?
    end
    super(trashed_by)
    update_flagged_posts_count
    self.topic_embed.trash! if has_topic_embed?
  end

  def recover!
    unless deleted_at.nil?
      update_category_topic_count_by(1)
      CategoryTagStat.topic_recovered(self) if self.tags.present?
    end
    super
    update_flagged_posts_count
    unless (topic_embed = TopicEmbed.with_deleted.find_by_topic_id(id)).nil?
      topic_embed.recover!
    end
  end

  rate_limit :default_rate_limiter
  rate_limit :limit_topics_per_day
  rate_limit :limit_private_messages_per_day

  validates :title, if: Proc.new { |t| t.new_record? || t.title_changed? },
                    presence: true,
                    topic_title_length: true,
                    censored_words: true,
                    quality_title: { unless: :private_message? },
                    max_emojis: true,
                    unique_among: { unless: Proc.new { |t| (SiteSetting.allow_duplicate_topic_titles? || t.private_message?) },
                                    message: :has_already_been_used,
                                    allow_blank: true,
                                    case_sensitive: false,
                                    collection: Proc.new { Topic.listable_topics } }

  validates :category_id,
            presence: true,
            exclusion: {
              in: Proc.new { [SiteSetting.uncategorized_category_id] }
            },
            if: Proc.new { |t|
              (t.new_record? || t.category_id_changed?) &&
              !SiteSetting.allow_uncategorized_topics &&
              (t.archetype.nil? || t.regular?) &&
              (!t.user_id || !t.user.staff?)
            }

  validates :featured_link, allow_nil: true, url: true
  validate if: :featured_link do
    errors.add(:featured_link, :invalid_category) unless !featured_link_changed? ||
      Guardian.new.can_edit_featured_link?(category_id)
  end

  before_validation do
    self.title = TextCleaner.clean_title(TextSentinel.title_sentinel(title).text) if errors[:title].empty?
    self.featured_link = self.featured_link.strip.presence if self.featured_link
  end

  belongs_to :category
  has_many :category_users, through: :category
  has_many :posts
  has_many :ordered_posts, -> { order(post_number: :asc) }, class_name: "Post"
  has_many :topic_allowed_users
  has_many :topic_allowed_groups

  has_many :group_archived_messages, dependent: :destroy
  has_many :user_archived_messages, dependent: :destroy

  has_many :allowed_groups, through: :topic_allowed_groups, source: :group
  has_many :allowed_group_users, through: :allowed_groups, source: :users
  has_many :allowed_users, through: :topic_allowed_users, source: :user
  has_many :queued_posts

  has_many :topic_tags
  has_many :tags, through: :topic_tags, dependent: :destroy # dependent destroy applies to the topic_tags records
  has_many :tag_users, through: :tags

  has_one :top_topic
  has_one :shared_draft, dependent: :destroy

  belongs_to :user
  belongs_to :last_poster, class_name: 'User', foreign_key: :last_post_user_id
  belongs_to :featured_user1, class_name: 'User', foreign_key: :featured_user1_id
  belongs_to :featured_user2, class_name: 'User', foreign_key: :featured_user2_id
  belongs_to :featured_user3, class_name: 'User', foreign_key: :featured_user3_id
  belongs_to :featured_user4, class_name: 'User', foreign_key: :featured_user4_id

  has_many :topic_users
  has_many :topic_links
  has_many :topic_invites
  has_many :invites, through: :topic_invites, source: :invite
  has_many :topic_timers, dependent: :destroy

  has_one :user_warning
  has_one :first_post, -> { where post_number: 1 }, class_name: 'Post'
  has_one :topic_search_data
  has_one :topic_embed, dependent: :destroy

  # When we want to temporarily attach some data to a forum topic (usually before serialization)
  attr_accessor :user_data

  attr_accessor :posters  # TODO: can replace with posters_summary once we remove old list code
  attr_accessor :participants
  attr_accessor :topic_list
  attr_accessor :meta_data
  attr_accessor :include_last_poster
  attr_accessor :import_mode # set to true to optimize creation and save for imports

  # The regular order
  scope :topic_list_order, -> { order('topics.bumped_at desc') }

  # Return private message topics
  scope :private_messages, -> { where(archetype: Archetype.private_message) }

  scope :listable_topics, -> { where('topics.archetype <> ?', Archetype.private_message) }

  scope :by_newest, -> { order('topics.created_at desc, topics.id desc') }

  scope :visible, -> { where(visible: true) }

  scope :created_since, lambda { |time_ago| where('topics.created_at > ?', time_ago) }

  scope :secured, lambda { |guardian = nil|
    ids = guardian.secure_category_ids if guardian

    # Query conditions
    condition = if ids.present?
      ["NOT read_restricted OR id IN (:cats)", cats: ids]
    else
      ["NOT read_restricted"]
    end

    where("topics.category_id IS NULL OR topics.category_id IN (SELECT id FROM categories WHERE #{condition[0]})", condition[1])
  }

  IN_CATEGORY_AND_SUBCATEGORIES_SQL = <<~SQL
       t.category_id = :category_id
    OR t.category_id IN (SELECT id FROM categories WHERE categories.parent_category_id = :category_id)
  SQL

  scope :in_category_and_subcategories, lambda { |category_id|
    where("topics.category_id = ? OR topics.category_id IN (SELECT id FROM categories WHERE categories.parent_category_id = ?)",
        category_id,
        category_id) if category_id
  }

  scope :with_subtype, ->(subtype) { where('topics.subtype = ?', subtype) }

  attr_accessor :ignore_category_auto_close
  attr_accessor :skip_callbacks

  before_create do
    initialize_default_values
  end

  after_create do
    unless skip_callbacks
      changed_to_category(category)
      advance_draft_sequence
    end
  end

  before_save do
    unless skip_callbacks
      ensure_topic_has_a_category
    end

    if title_changed?
      write_attribute(:fancy_title, Topic.fancy_title(title))
    end

    if category_id_changed? || new_record?
      inherit_auto_close_from_category
    end
  end

  after_save do
    banner = "banner".freeze

    if archetype_before_last_save == banner || archetype == banner
      ApplicationController.banner_json_cache.clear
    end

    if tags_changed || saved_change_to_attribute?(:category_id)

      SearchIndexer.queue_post_reindex(self.id)

      if tags_changed
        TagUser.auto_watch(topic_id: id)
        TagUser.auto_track(topic_id: id)
        self.tags_changed = false
      end
    end

    SearchIndexer.index(self)
    UserActionCreator.log_topic(self)
  end

  after_update do
    if saved_changes[:category_id] && self.tags.present?
      CategoryTagStat.topic_moved(self, *saved_changes[:category_id])
    end
  end

  def initialize_default_values
    self.bumped_at ||= Time.now
    self.last_post_user_id ||= user_id
  end

  def inherit_auto_close_from_category
    if !self.closed &&
       !@ignore_category_auto_close &&
       self.category &&
       self.category.auto_close_hours &&
       !public_topic_timer&.execute_at

      self.set_or_create_timer(
        TopicTimer.types[:close],
        self.category.auto_close_hours,
        based_on_last_post: self.category.auto_close_based_on_last_post
      )
    end
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

  def self.visible_post_types(viewed_by = nil)
    types = Post.types
    result = [types[:regular], types[:moderator_action], types[:small_action]]
    result << types[:whisper] if viewed_by&.staff?
    result
  end

  def self.top_viewed(max = 10)
    Topic.listable_topics.visible.secured.order('views desc').limit(max)
  end

  def self.recent(max = 10)
    Topic.listable_topics.visible.secured.order('created_at desc').limit(max)
  end

  def self.count_exceeds_minimum?
    count > SiteSetting.minimum_topics_similar
  end

  def best_post
    posts.where(post_type: Post.types[:regular], user_deleted: false).order('score desc nulls last').limit(1).first
  end

  def has_flags?
    FlagQuery.flagged_post_actions(filter: "active")
      .where("topics.id" => id)
      .exists?
  end

  def is_official_warning?
    subtype == TopicSubtype.moderator_warning
  end

  # all users (in groups or directly targetted) that are going to get the pm
  def all_allowed_users
    moderators_sql = " UNION #{User.moderators.to_sql}" if private_message? && (has_flags? || is_official_warning?)
    User.from("(#{allowed_users.to_sql} UNION #{allowed_group_users.to_sql}#{moderators_sql}) as users")
  end

  # Additional rate limits on topics: per day and private messages per day
  def limit_topics_per_day
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
        DB.exec("UPDATE topics SET fancy_title = :fancy_title where id = :id", id: self.id, fancy_title: fancy_title)
      end
    end

    fancy_title
  end

  def pending_posts_count
    queued_posts.new_count
  end

  # Returns hot topics since a date for display in email digest.
  def self.for_digest(user, since, opts = nil)
    opts = opts || {}
    score = "#{ListController.best_period_for(since)}_score"

    topics = Topic
      .visible
      .secured(Guardian.new(user))
      .joins("LEFT OUTER JOIN topic_users ON topic_users.topic_id = topics.id AND topic_users.user_id = #{user.id.to_i}")
      .joins("LEFT OUTER JOIN category_users ON category_users.category_id = topics.category_id AND category_users.user_id = #{user.id.to_i}")
      .joins("LEFT OUTER JOIN users ON users.id = topics.user_id")
      .where(closed: false, archived: false)
      .where("COALESCE(topic_users.notification_level, 1) <> ?", TopicUser.notification_levels[:muted])
      .created_since(since)
      .where('topics.created_at < ?', (SiteSetting.editing_grace_period || 0).seconds.ago)
      .listable_topics
      .includes(:category)

    unless opts[:include_tl0] || user.user_option.try(:include_tl0_in_digests)
      topics = topics.where("COALESCE(users.trust_level, 0) > 0")
    end

    if !!opts[:top_order]
      topics = topics.joins("LEFT OUTER JOIN top_topics ON top_topics.topic_id = topics.id")
        .order(TopicQuerySQL.order_top_with_notification_levels(score))
    end

    if opts[:limit]
      topics = topics.limit(opts[:limit])
    end

    # Remove category topics
    category_topic_ids = Category.pluck(:topic_id).compact!
    if category_topic_ids.present?
      topics = topics.where("topics.id NOT IN (?)", category_topic_ids)
    end

    # Remove muted categories
    muted_category_ids = CategoryUser.where(user_id: user.id, notification_level: CategoryUser.notification_levels[:muted]).pluck(:category_id)
    if SiteSetting.digest_suppress_categories.present?
      muted_category_ids += SiteSetting.digest_suppress_categories.split("|").map(&:to_i)
      muted_category_ids = muted_category_ids.uniq
    end
    if muted_category_ids.present?
      topics = topics.where("topics.category_id NOT IN (?)", muted_category_ids)
    end

    # Remove muted tags
    muted_tag_ids = TagUser.lookup(user, :muted).pluck(:tag_id)
    unless muted_tag_ids.empty?
      # If multiple tags per topic, include topics with tags that aren't muted,
      # and don't forget untagged topics.
      topics = topics.where(
        "EXISTS ( SELECT 1 FROM topic_tags WHERE topic_tags.topic_id = topics.id AND tag_id NOT IN (?) )
        OR NOT EXISTS (SELECT 1 FROM topic_tags WHERE topic_tags.topic_id = topics.id)", muted_tag_ids)
    end

    topics
  end

  # Using the digest query, figure out what's  new for a user since last seen
  def self.new_since_last_seen(user, since, featured_topic_ids = nil)
    topics = Topic.for_digest(user, since)
    featured_topic_ids ? topics.where("topics.id NOT IN (?)", featured_topic_ids) : topics
  end

  def meta_data=(data)
    custom_fields.replace(data)
  end

  def meta_data
    custom_fields
  end

  def update_meta_data(data)
    custom_fields.update(data)
    save
  end

  def reload(options = nil)
    @post_numbers = nil
    @public_topic_timer = nil
    @private_topic_timer = nil
    @is_category_topic = nil
    super(options)
  end

  def post_numbers
    @post_numbers ||= posts.order(:post_number).pluck(:post_number)
  end

  def age_in_minutes
    ((Time.zone.now - created_at) / 1.minute).round
  end

  def self.listable_count_per_day(start_date, end_date, category_id = nil)
    result = listable_topics.where("topics.created_at >= ? AND topics.created_at <= ?", start_date, end_date)
    result = result.group('date(topics.created_at)').order('date(topics.created_at)')
    result = result.where(category_id: category_id) if category_id
    result.count
  end

  def private_message?
    archetype == Archetype.private_message
  end

  def regular?
    self.archetype == Archetype.default
  end

  MAX_SIMILAR_BODY_LENGTH ||= 200

  def self.similar_to(title, raw, user = nil)
    return [] if title.blank?
    raw = raw.presence || ""

    search_data = "#{title} #{raw[0...MAX_SIMILAR_BODY_LENGTH]}".strip
    filter_words = Search.prepare_data(search_data)
    ts_query = Search.ts_query(term: filter_words, joiner: "|")

    candidates = Topic
      .visible
      .listable_topics
      .secured(Guardian.new(user))
      .joins("JOIN topic_search_data s ON topics.id = s.topic_id")
      .joins("LEFT JOIN categories c ON topics.id = c.topic_id")
      .where("search_data @@ #{ts_query}")
      .where("c.topic_id IS NULL")
      .order("ts_rank(search_data, #{ts_query}) DESC")
      .limit(SiteSetting.max_similar_results * 3)

    candidate_ids = candidates.pluck(:id)

    return [] if candidate_ids.blank?

    similars = Topic
      .joins("JOIN posts AS p ON p.topic_id = topics.id AND p.post_number = 1")
      .where("topics.id IN (?)", candidate_ids)
      .order("similarity DESC")
      .limit(SiteSetting.max_similar_results)

    if raw.present?
      similars
        .select(sanitize_sql_array(["topics.*, similarity(topics.title, :title) + similarity(p.raw, :raw) AS similarity, p.cooked AS blurb", title: title, raw: raw]))
        .where("similarity(topics.title, :title) + similarity(p.raw, :raw) > 0.2", title: title, raw: raw)
    else
      similars
        .select(sanitize_sql_array(["topics.*, similarity(topics.title, :title) AS similarity, p.cooked AS blurb", title: title]))
        .where("similarity(topics.title, :title) > 0.2", title: title)
    end
  end

  def update_status(status, enabled, user, opts = {})
    TopicStatusUpdater.new(self, user).update!(status, enabled, opts)
    DiscourseEvent.trigger(:topic_status_updated, self, status, enabled)
  end

  # Atomically creates the next post number
  def self.next_post_number(topic_id, reply = false, whisper = false)
    highest = DB.query_single("SELECT coalesce(max(post_number),0) AS max FROM posts WHERE topic_id = ?", topic_id).first.to_i

    if whisper

      result = DB.query_single(<<~SQL, highest, topic_id)
        UPDATE topics
        SET highest_staff_post_number = ? + 1
        WHERE id = ?
        RETURNING highest_staff_post_number
      SQL

      result.first.to_i

    else

      reply_sql = reply ? ", reply_count = reply_count + 1" : ""

      result = DB.query_single(<<~SQL, highest: highest, topic_id: topic_id)
        UPDATE topics
        SET highest_staff_post_number = :highest + 1,
            highest_post_number = :highest + 1#{reply_sql},
            posts_count = posts_count + 1
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
      )
      UPDATE topics
      SET
        highest_staff_post_number = X.highest_post_number,
        highest_post_number = Y.highest_post_number,
        last_posted_at = Y.last_posted_at,
        posts_count = Y.posts_count
      FROM X, Y
      WHERE
        X.topic_id = topics.id AND
        Y.topic_id = topics.id AND (
          topics.highest_staff_post_number <> X.highest_post_number OR
          topics.highest_post_number <> Y.highest_post_number OR
          topics.last_posted_at <> Y.last_posted_at OR
          topics.posts_count <> Y.posts_count
        )
    SQL
  end

  # If a post is deleted we have to update our highest post counters
  def self.reset_highest(topic_id)
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
        ),
        posts_count = (
          SELECT count(*) FROM posts
          WHERE deleted_at IS NULL AND
                topic_id = :topic_id AND
                post_type <> 4
        ),

        last_posted_at = (
          SELECT MAX(created_at) FROM posts
          WHERE topic_id = :topic_id AND
                deleted_at IS NULL AND
                post_type <> 4
        )
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
                                  END,
          highest_seen_post_number = CASE
                            WHEN highest_seen_post_number > :highest THEN :highest
                            ELSE highest_seen_post_number
                            END
      WHERE topic_id = :topic_id
    SQL
  end

  # This calculates the geometric mean of the posts and stores it with the topic
  def self.calculate_avg_time(min_topic_age = nil)
    builder = DB.build <<~SQL
      UPDATE topics
      SET avg_time = x.gmean
      FROM (SELECT topic_id,
                   round(exp(avg(ln(avg_time)))) AS gmean
            FROM posts
            WHERE avg_time > 0 AND avg_time IS NOT NULL
            GROUP BY topic_id) AS x
      /*where*/
    SQL

    builder.where <<~SQL
      x.topic_id = topics.id AND
      (topics.avg_time <> x.gmean OR topics.avg_time IS NULL)
    SQL

    if min_topic_age
      builder.where("topics.bumped_at > :bumped_at", bumped_at: min_topic_age)
    end

    builder.exec
  end

  def changed_to_category(new_category)
    return true if new_category.blank? || Category.exists?(topic_id: id)
    return false if new_category.id == SiteSetting.uncategorized_category_id && !SiteSetting.allow_uncategorized_topics

    Topic.transaction do
      old_category = category

      if self.category_id != new_category.id
        self.update_attribute(:category_id, new_category.id)

        if old_category
          Category
            .where(id: old_category.id)
            .update_all("topic_count = topic_count - 1")
        end

        # when a topic changes category we may have to start watching it
        # if we happen to have read state for it
        CategoryUser.auto_watch(category_id: new_category.id, topic_id: self.id)
        CategoryUser.auto_track(category_id: new_category.id, topic_id: self.id)

        if post = self.ordered_posts.first
          notified_user_ids = [post.user_id, post.last_editor_id].uniq
          DB.after_commit do
            Jobs.enqueue(:notify_category_change, post_id: post.id, notified_user_ids: notified_user_ids)
          end
        end
      end

      Category.where(id: new_category.id).update_all("topic_count = topic_count + 1")
      CategoryFeaturedTopic.feature_topics_for(old_category) unless @import_mode
      CategoryFeaturedTopic.feature_topics_for(new_category) unless @import_mode || old_category.try(:id) == new_category.id
    end

    true
  end

  def add_small_action(user, action_code, who = nil, opts = {})
    custom_fields = {}
    custom_fields["action_code_who"] = who if who.present?
    opts = opts.merge(
      post_type: Post.types[:small_action],
      action_code: action_code,
      custom_fields: custom_fields
    )

    add_moderator_post(user, nil, opts)
  end

  def add_moderator_post(user, text, opts = nil)
    opts ||= {}
    new_post = nil
    creator = PostCreator.new(user,
                              raw: text,
                              post_type: opts[:post_type] || Post.types[:moderator_action],
                              action_code: opts[:action_code],
                              no_bump: opts[:bump].blank?,
                              topic_id: self.id,
                              skip_validations: true,
                              custom_fields: opts[:custom_fields])

    if (new_post = creator.create) && new_post.present?
      increment!(:moderator_posts_count) if new_post.persisted?
      # If we are moving posts, we want to insert the moderator post where the previous posts were
      # in the stream, not at the end.
      new_post.update_attributes!(post_number: opts[:post_number], sort_order: opts[:post_number]) if opts[:post_number].present?

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

    changed_to_category(cat)
  end

  def remove_allowed_group(removed_by, name)
    if group = Group.find_by(name: name)
      group_user = topic_allowed_groups.find_by(group_id: group.id)
      if group_user
        group_user.destroy
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
        topic_user.destroy

        if user.id == removed_by&.id
          removed_by = Discourse.system_user
          add_small_action(removed_by, "user_left", user.username)
        else
          add_small_action(removed_by, "removed_user", user.username)
        end

        return true
      end
    end

    false
  end

  def reached_recipients_limit?
    return false unless private_message?
    topic_allowed_users.count + topic_allowed_groups.count >= SiteSetting.max_allowed_message_recipients
  end

  def invite_group(user, group)
    TopicAllowedGroup.create!(topic_id: id, group_id: group.id)

    last_post = posts.order('post_number desc').where('not hidden AND posts.deleted_at IS NULL').first
    if last_post
      Jobs.enqueue(:post_alert, post_id: last_post.id)
      add_small_action(user, "invited_group", group.name)

      group_id = group.id

      group.users.where(
        "group_users.notification_level > ? AND user_id != ?",
        NotificationLevels.all[:muted], user.id
      ).find_each do |u|

        u.notifications.create!(
          notification_type: Notification.types[:invited_to_private_message],
          topic_id: self.id,
          post_number: 1,
          data: {
            topic_title: self.title,
            display_username: user.username,
            group_id: group_id
          }.to_json
        )
      end
    end

    true
  end

  def invite(invited_by, username_or_email, group_ids = nil, custom_message = nil)
    target_user = User.find_by_username_or_email(username_or_email)
    guardian = Guardian.new(invited_by)
    is_email = username_or_email =~ /^.+@.+$/

    if target_user
      if topic_allowed_users.exists?(user_id: target_user.id)
        raise UserExists.new(I18n.t("topic_invite.user_exists"))
      end

      if invite_existing_muted?(target_user, invited_by)
        return true
      end

      if private_message?
        !!invite_to_private_message(invited_by, target_user, guardian)
      else
        !!invite_to_topic(invited_by, target_user, group_ids, guardian)
      end
    elsif is_email && guardian.can_invite_via_email?(self)
      !!Invite.invite_by_email(
        username_or_email, invited_by, self, group_ids, custom_message
      )
    end
  end

  def invite_existing_muted?(target_user, invited_by)
    if invited_by.id &&
       MutedUser.where(user_id: target_user.id, muted_user_id: invited_by.id)
           .joins(:muted_user)
           .where('NOT admin AND NOT moderator')
           .exists?
      return true
    end

    if TopicUser.where(
         topic: self,
         user: target_user,
         notification_level: TopicUser.notification_levels[:muted]
        ).exists?
      return true
    end

    false
  end

  def email_already_exists_for?(invite)
    invite.email_already_exists && private_message?
  end

  def grant_permission_to_user(lower_email)
    user = User.find_by_email(lower_email)
    topic_allowed_users.create!(user_id: user.id)
  end

  def max_post_number
    posts.with_deleted.maximum(:post_number).to_i
  end

  def move_posts(moved_by, post_ids, opts)
    post_mover = PostMover.new(self, moved_by, post_ids, move_to_pm: opts[:archetype].present? && opts[:archetype] == "private_message")

    if opts[:destination_topic_id]
      topic = post_mover.to_topic(opts[:destination_topic_id], participants: opts[:participants])

      DiscourseEvent.trigger(:topic_merged,
        post_mover.original_topic,
        post_mover.destination_topic
      )

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

  def update_flagged_posts_count
    PostAction.update_flagged_posts_count
  end

  def update_action_counts
    update_column(:like_count, Post.where(topic_id: id).sum(:like_count))
  end

  def posters_summary(options = {}) # avatar lookup in options
    @posters_summary ||= TopicPostersSummary.new(self, options).summary
  end

  def participants_summary(options = {})
    @participants_summary ||= TopicParticipantsSummary.new(self, options).summary
  end

  def make_banner!(user)
    # only one banner at the same time
    previous_banner = Topic.where(archetype: Archetype.banner).first
    previous_banner.remove_banner!(user) if previous_banner.present?

    UserProfile.where("dismissed_banner_key IS NOT NULL")
      .update_all(dismissed_banner_key: nil)

    self.archetype = Archetype.banner
    self.add_small_action(user, "banner.enabled")
    self.save

    MessageBus.publish('/site/banner', banner)
  end

  def remove_banner!(user)
    self.archetype = Archetype.default
    self.add_small_action(user, "banner.disabled")
    self.save

    MessageBus.publish('/site/banner', nil)
  end

  def banner
    post = self.ordered_posts.first

    {
      html: post.cooked,
      key: self.id,
      url: self.url
    }
  end

  # Even if the slug column in the database is null, topic.slug will return something:
  def slug
    unless slug = read_attribute(:slug)
      return '' unless title.present?
      slug = Slug.for(title)
      if new_record?
        write_attribute(:slug, slug)
      else
        update_column(:slug, slug)
      end
    end

    slug
  end

  def title=(t)
    slug = Slug.for(t.to_s)
    write_attribute(:slug, slug)
    write_attribute(:fancy_title, nil)
    write_attribute(:title, t)
  end

  # NOTE: These are probably better off somewhere else.
  #       Having a model know about URLs seems a bit strange.
  def last_post_url
    "#{Discourse.base_uri}/t/#{slug}/#{id}/#{posts_count}"
  end

  def self.url(id, slug, post_number = nil)
    url = "#{Discourse.base_url}/t/#{slug}/#{id}"
    url << "/#{post_number}" if post_number.to_i > 1
    url
  end

  def url(post_number = nil)
    self.class.url id, slug, post_number
  end

  def self.relative_url(id, slug, post_number = nil)
    url = "#{Discourse.base_uri}/t/"
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
    return unless user.present?
    TopicUser.change(user.id, id, cleared_pinned_at: Time.now)
  end

  def re_pin_for(user)
    return unless user.present?
    TopicUser.change(user.id, id, cleared_pinned_at: nil)
  end

  def update_pinned(status, global = false, pinned_until = "")
    pinned_until ||= ''

    pinned_until = begin
      Time.parse(pinned_until)
    rescue ArgumentError
    end

    update_columns(
      pinned_at: status ? Time.zone.now : nil,
      pinned_globally: global,
      pinned_until: pinned_until
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
    if user && user.id
      notifier.muted?(user.id)
    end
  end

  def self.ensure_consistency!
    # unpin topics that might have been missed
    Topic.where("pinned_until < now()").update_all(pinned_at: nil, pinned_globally: false, pinned_until: nil)
  end

  def public_topic_timer
    @public_topic_timer ||= topic_timers.find_by(deleted_at: nil, public_type: true)
  end

  def private_topic_timer(user)
    @private_topic_Timer ||= topic_timers.find_by(deleted_at: nil, public_type: false, user_id: user.id)
  end

  def delete_topic_timer(status_type, by_user: Discourse.system_user)
    options = { status_type: status_type }
    options.merge!(user: by_user) unless TopicTimer.public_types[status_type]
    self.topic_timers.find_by(options)&.trash!(by_user)
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
  def set_or_create_timer(status_type, time, by_user: nil, based_on_last_post: false, category_id: SiteSetting.uncategorized_category_id)
    return delete_topic_timer(status_type, by_user: by_user) if time.blank?

    public_topic_timer = !!TopicTimer.public_types[status_type]
    topic_timer_options = { topic: self, public_type: public_topic_timer }
    topic_timer_options.merge!(user: by_user) unless public_topic_timer
    topic_timer = TopicTimer.find_or_initialize_by(topic_timer_options)
    topic_timer.status_type = status_type

    time_now = Time.zone.now
    topic_timer.based_on_last_post = !based_on_last_post.blank?

    if status_type == TopicTimer.types[:publish_to_category]
      topic_timer.category = Category.find_by(id: category_id)
    end

    if topic_timer.based_on_last_post
      num_hours = time.to_f

      if num_hours > 0
        last_post_created_at = self.ordered_posts.last.present? ? self.ordered_posts.last.created_at : time_now
        topic_timer.execute_at = last_post_created_at + num_hours.hours
        topic_timer.created_at = last_post_created_at
      end
    else
      utc = Time.find_zone("UTC")
      is_float = (Float(time) rescue nil)

      if is_float
        num_hours = time.to_f
        topic_timer.execute_at = num_hours.hours.from_now if num_hours > 0
      else
        timestamp = utc.parse(time)
        raise Discourse::InvalidParameters unless timestamp
        # a timestamp in client's time zone, like "2015-5-27 12:00"
        topic_timer.execute_at = timestamp
        topic_timer.errors.add(:execute_at, :invalid) if timestamp < utc.now
      end
    end

    if topic_timer.execute_at
      if by_user&.staff? || by_user&.trust_level == TrustLevel[4]
        topic_timer.user = by_user
      else
        topic_timer.user ||= (self.user.staff? || self.user.trust_level == TrustLevel[4] ? self.user : Discourse.system_user)
      end

      if self.persisted?
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

  def acting_user
    @acting_user || user
  end

  def acting_user=(u)
    @acting_user = u
  end

  def secure_group_ids
    @secure_group_ids ||= if self.category && self.category.read_restricted?
      self.category.secure_group_ids
    end
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

  TIME_TO_FIRST_RESPONSE_SQL ||= <<-SQL
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

  TIME_TO_FIRST_RESPONSE_TOTAL_SQL ||= <<-SQL
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
    builder.where(IN_CATEGORY_AND_SUBCATEGORIES_SQL, category_id: opts[:category_id]) if opts[:category_id]
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
    time_to_first_response(TIME_TO_FIRST_RESPONSE_SQL, opts.merge(start_date: start_date, end_date: end_date))
  end

  def self.time_to_first_response_total(opts = nil)
    total = time_to_first_response(TIME_TO_FIRST_RESPONSE_TOTAL_SQL, opts)
    total.first["hours"].to_f.round(2)
  end

  WITH_NO_RESPONSE_SQL ||= <<-SQL
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

  def self.with_no_response_per_day(start_date, end_date, category_id = nil)
    builder = DB.build(WITH_NO_RESPONSE_SQL)
    builder.where("t.created_at >= :start_date", start_date: start_date) if start_date
    builder.where("t.created_at < :end_date", end_date: end_date) if end_date
    builder.where(IN_CATEGORY_AND_SUBCATEGORIES_SQL, category_id: category_id) if category_id
    builder.where("t.archetype <> '#{Archetype.private_message}'")
    builder.where("t.deleted_at IS NULL")
    builder.query_hash
  end

  WITH_NO_RESPONSE_TOTAL_SQL ||= <<-SQL
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
    builder.where(IN_CATEGORY_AND_SUBCATEGORIES_SQL, category_id: opts[:category_id]) if opts[:category_id]
    builder.where("t.archetype <> '#{Archetype.private_message}'")
    builder.where("t.deleted_at IS NULL")
    builder.query_single.first.to_i
  end

  def convert_to_public_topic(user)
    public_topic = TopicConverter.new(self, user).convert_to_public_topic
    add_small_action(user, "public_topic") if public_topic
    public_topic
  end

  def convert_to_private_message(user)
    private_topic = TopicConverter.new(self, user).convert_to_private_message
    add_small_action(user, "private_topic") if private_topic
    private_topic
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
    MiniSuffix.domain(URI.parse(URI.encode(self.featured_link)).hostname)
  end

  def self.private_message_topics_count_per_day(start_date, end_date, topic_subtype)
    private_messages
      .with_subtype(topic_subtype)
      .where('topics.created_at >= ? AND topics.created_at <= ?', start_date, end_date)
      .group('date(topics.created_at)')
      .order('date(topics.created_at)')
      .count
  end

  def is_category_topic?
    @is_category_topic ||= Category.exists?(topic_id: self.id.to_i)
  end

  def reset_bumped_at
    post = ordered_posts.where(
      user_deleted: false,
      hidden: false,
      post_type: Post.types[:regular]
    ).last || first_post

    update!(bumped_at: post.created_at)
  end

  private

  def invite_to_private_message(invited_by, target_user, guardian)
    if !guardian.can_send_private_message?(target_user)
      raise UserExists.new(I18n.t(
        "activerecord.errors.models.topic.attributes.base.cant_send_pm"
      ))
    end

    Topic.transaction do
      rate_limit_topic_invitation(invited_by)
      topic_allowed_users.create!(user_id: target_user.id)
      add_small_action(invited_by, "invited_user", target_user.username)

      create_invite_notification!(
        target_user,
        Notification.types[:invited_to_private_message],
        invited_by.username
      )
    end
  end

  def invite_to_topic(invited_by, target_user, group_ids, guardian)
    Topic.transaction do
      rate_limit_topic_invitation(invited_by)

      if group_ids
        (
          self.category.groups.where(id: group_ids).where(automatic: false) -
          target_user.groups.where(automatic: false)
        ).each do |group|
          if guardian.can_edit_group?(group)
            group.add(target_user)

            GroupActionLogger
              .new(invited_by, group)
              .log_add_user_to_group(target_user)
          end
        end
      end

      if Guardian.new(target_user).can_see_topic?(self)
        create_invite_notification!(
          target_user,
          Notification.types[:invited_to_topic],
          invited_by.username
        )
      end
    end
  end

  def update_category_topic_count_by(num)
    if category_id.present?
      Category.where(['id = ?', category_id]).update_all("topic_count = topic_count " + (num > 0 ? '+' : '') + "#{num}")
    end
  end

  def limit_first_day_topics_per_day
    apply_per_day_rate_limit_for("first-day-topics", :max_topics_in_first_day)
  end

  def apply_per_day_rate_limit_for(key, method_name)
    RateLimiter.new(user, "#{key}-per-day", SiteSetting.send(method_name), 1.day.to_i)
  end

  def create_invite_notification!(target_user, notification_type, username)
    target_user.notifications.create!(
      notification_type: notification_type,
      topic_id: self.id,
      post_number: 1,
      data: {
        topic_title: self.title,
        display_username: username
      }.to_json
    )
  end

  def rate_limit_topic_invitation(invited_by)
    RateLimiter.new(
      invited_by,
      "topic-invitations-per-day",
      SiteSetting.max_topic_invitations_per_day,
      1.day.to_i
    ).performed!

    true
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
#  avg_time                  :integer
#  deleted_at                :datetime
#  highest_post_number       :integer          default(0), not null
#  image_url                 :string
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
#  subtype                   :string
#  slug                      :string
#  deleted_by_id             :integer
#  participant_count         :integer          default(1)
#  word_count                :integer
#  excerpt                   :string(1000)
#  pinned_globally           :boolean          default(FALSE), not null
#  pinned_until              :datetime
#  fancy_title               :string(400)
#  highest_staff_post_number :integer          default(0), not null
#  featured_link             :string
#
# Indexes
#
#  idx_topics_front_page                   (deleted_at,visible,archetype,category_id,id)
#  idx_topics_user_id_deleted_at           (user_id) WHERE (deleted_at IS NULL)
#  idxtopicslug                            (slug) WHERE ((deleted_at IS NULL) AND (slug IS NOT NULL))
#  index_topics_on_bumped_at               (bumped_at)
#  index_topics_on_created_at_and_visible  (created_at,visible) WHERE ((deleted_at IS NULL) AND ((archetype)::text <> 'private_message'::text))
#  index_topics_on_id_and_deleted_at       (id,deleted_at)
#  index_topics_on_lower_title             (lower((title)::text))
#  index_topics_on_pinned_at               (pinned_at) WHERE (pinned_at IS NOT NULL)
#  index_topics_on_pinned_globally         (pinned_globally) WHERE pinned_globally
#
