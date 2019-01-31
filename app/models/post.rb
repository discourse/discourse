require_dependency 'pretty_text'
require_dependency 'rate_limiter'
require_dependency 'post_revisor'
require_dependency 'enum'
require_dependency 'post_analyzer'
require_dependency 'validators/post_validator'
require_dependency 'plugin/filter'

require 'archetype'
require 'digest/sha1'

class Post < ActiveRecord::Base
  # TODO: Remove this after 19th Dec 2018
  self.ignored_columns = %w{vote_count}

  include RateLimiter::OnCreateRecord
  include Trashable
  include Searchable
  include HasCustomFields
  include LimitedEdit

  cattr_accessor :plugin_permitted_create_params
  self.plugin_permitted_create_params = {}

  # increase this number to force a system wide post rebake
  # Version 1, was the initial version
  # Version 2 15-12-2017, introduces CommonMark and a huge number of onebox fixes
  BAKED_VERSION = 2

  rate_limit
  rate_limit :limit_posts_per_day

  belongs_to :user
  belongs_to :topic

  belongs_to :reply_to_user, class_name: "User"

  has_many :post_replies
  has_many :replies, through: :post_replies
  has_many :post_actions
  has_many :topic_links
  has_many :group_mentions, dependent: :destroy

  has_many :post_uploads
  has_many :uploads, through: :post_uploads

  has_one :post_stat

  has_one :incoming_email

  has_many :post_details

  has_many :post_revisions
  has_many :revisions, -> { order(:number) }, foreign_key: :post_id, class_name: 'PostRevision'

  has_many :user_actions, foreign_key: :target_post_id

  validates_with ::Validators::PostValidator, unless: :skip_validation

  after_save :index_search
  after_save :create_user_action

  # We can pass several creating options to a post via attributes
  attr_accessor :image_sizes, :quoted_post_numbers, :no_bump, :invalidate_oneboxes, :cooking_options, :skip_unique_check, :skip_validation

  LARGE_IMAGES      ||= "large_images".freeze
  BROKEN_IMAGES     ||= "broken_images".freeze
  DOWNLOADED_IMAGES ||= "downloaded_images".freeze

  SHORT_POST_CHARS ||= 1200

  scope :private_posts_for_user, ->(user) {
    where("posts.topic_id IN (SELECT topic_id
             FROM topic_allowed_users
             WHERE user_id = :user_id
             UNION ALL
             SELECT tg.topic_id
             FROM topic_allowed_groups tg
             JOIN group_users gu ON gu.user_id = :user_id AND
                                      gu.group_id = tg.group_id)",
                                              user_id: user.id)
  }

  scope :by_newest, -> { order('created_at DESC, id DESC') }
  scope :by_post_number, -> { order('post_number ASC') }
  scope :with_user, -> { includes(:user) }
  scope :created_since, -> (time_ago) { where('posts.created_at > ?', time_ago) }
  scope :public_posts, -> { joins(:topic).where('topics.archetype <> ?', Archetype.private_message) }
  scope :private_posts, -> { joins(:topic).where('topics.archetype = ?', Archetype.private_message) }
  scope :with_topic_subtype, ->(subtype) { joins(:topic).where('topics.subtype = ?', subtype) }
  scope :visible, -> { joins(:topic).where('topics.visible = true').where(hidden: false) }
  scope :secured, -> (guardian) { where('posts.post_type IN (?)', Topic.visible_post_types(guardian&.user)) }
  scope :for_mailing_list, ->(user, since) {
    q = created_since(since)
      .joins(:topic)
      .where(topic: Topic.for_digest(user, Time.at(0))) # we want all topics with new content, regardless when they were created

    q = q.where.not(post_type: Post.types[:whisper]) unless user.staff?

    q.order('posts.created_at ASC')
  }
  scope :raw_match, -> (pattern, type = 'string') {
    type = type&.downcase

    case type
    when 'string'
      where('raw ILIKE ?', "%#{pattern}%")
    when 'regex'
      where('raw ~* ?', "(?n)#{pattern}")
    end
  }

  delegate :username, to: :user

  def self.hidden_reasons
    @hidden_reasons ||= Enum.new(flag_threshold_reached: 1,
                                 flag_threshold_reached_again: 2,
                                 new_user_spam_threshold_reached: 3,
                                 flagged_by_tl3_user: 4,
                                 email_spam_header_found: 5,
                                 flagged_by_tl4_user: 6)
  end

  def self.types
    @types ||= Enum.new(regular: 1,
                        moderator_action: 2,
                        small_action: 3,
                        whisper: 4)
  end

  def self.cook_methods
    @cook_methods ||= Enum.new(regular: 1,
                               raw_html: 2,
                               email: 3)
  end

  def self.find_by_detail(key, value)
    includes(:post_details).find_by(post_details: { key: key, value: value })
  end

  def whisper?
    post_type == Post.types[:whisper]
  end

  def add_detail(key, value, extra = nil)
    post_details.build(key: key, value: value, extra: extra)
  end

  def limit_posts_per_day
    if user && user.new_user_posting_on_first_day? && post_number && post_number > 1
      RateLimiter.new(user, "first-day-replies-per-day", SiteSetting.max_replies_in_first_day, 1.day.to_i)
    end
  end

  def publish_change_to_clients!(type, opts = {})
    # special failsafe for posts missing topics consistency checks should fix,
    # but message is safe to skip
    return unless topic

    message = {
      id: id,
      post_number: post_number,
      updated_at: Time.now,
      user_id: user_id,
      last_editor_id: last_editor_id,
      type: type,
      version: version
    }.merge(opts)

    publish_message!("/topic/#{topic_id}", message)
  end

  def publish_message!(channel, message, opts = {})
    return unless topic

    if Topic.visible_post_types.include?(post_type)
      if topic.private_message?
        opts[:user_ids] = User.human_users.where("admin OR moderator").pluck(:id)
        opts[:user_ids] |= topic.allowed_users.pluck(:id)
      else
        opts[:group_ids] = topic.secure_group_ids
      end
    else
      opts[:user_ids] = User.human_users
        .where("admin OR moderator OR id = ?", user_id)
        .pluck(:id)
    end

    MessageBus.publish(channel, message, opts)
  end

  def trash!(trashed_by = nil)
    self.topic_links.each(&:destroy)
    super(trashed_by)
  end

  def recover!
    super
    update_flagged_posts_count
    recover_public_post_actions
    TopicLink.extract_from(self)
    QuotedPost.extract_from(self)
    if topic && topic.category_id && topic.category
      topic.category.update_latest
    end
  end

  # The key we use in redis to ensure unique posts
  def unique_post_key
    "unique-post-#{user_id}:#{raw_hash}"
  end

  def store_unique_post_key
    if SiteSetting.unique_posts_mins > 0
      $redis.setex(unique_post_key, SiteSetting.unique_posts_mins.minutes.to_i, id)
    end
  end

  def matches_recent_post?
    post_id = $redis.get(unique_post_key)
    post_id != (nil) && post_id.to_i != (id)
  end

  def raw_hash
    return if raw.blank?
    Digest::SHA1.hexdigest(raw)
  end

  def self.white_listed_image_classes
    @white_listed_image_classes ||= ['avatar', 'favicon', 'thumbnail', 'emoji']
  end

  def post_analyzer
    @post_analyzers ||= {}
    @post_analyzers[raw_hash] ||= PostAnalyzer.new(raw, topic_id)
  end

  %w{raw_mentions
    linked_hosts
    image_count
    attachment_count
    link_count
    raw_links
    has_oneboxes?}.each do |attr|
    define_method(attr) do
      post_analyzer.send(attr)
    end
  end

  def add_nofollow?
    return false if user&.staff?
    user.blank? || SiteSetting.tl3_links_no_follow? || !user.has_trust_level?(TrustLevel[3])
  end

  def omit_nofollow?
    !add_nofollow?
  end

  def cook(raw, opts = {})
    # For some posts, for example those imported via RSS, we support raw HTML. In that
    # case we can skip the rendering pipeline.
    return raw if cook_method == Post.cook_methods[:raw_html]

    options = opts.dup
    options[:cook_method] = cook_method

    post_user = self.user
    options[:user_id] = post_user.id if post_user
    options[:omit_nofollow] = true if omit_nofollow?

    cooked = post_analyzer.cook(raw, options)

    new_cooked = Plugin::Filter.apply(:after_post_cook, self, cooked)

    if post_type == Post.types[:regular]
      if new_cooked != cooked && new_cooked.blank?
        Rails.logger.debug("Plugin is blanking out post: #{self.url}\nraw: #{raw}")
      elsif new_cooked.blank?
        Rails.logger.debug("Blank post detected post: #{self.url}\nraw: #{raw}")
      end
    end

    new_cooked
  end

  # Sometimes the post is being edited by someone else, for example, a mod.
  # If that's the case, they should not be bound by the original poster's
  # restrictions, for example on not posting images.
  def acting_user
    @acting_user || user
  end

  def acting_user=(pu)
    @acting_user = pu
  end

  def last_editor
    self.last_editor_id ? (User.find_by_id(self.last_editor_id) || user) : user
  end

  def whitelisted_spam_hosts
    hosts = SiteSetting
      .white_listed_spam_host_domains
      .split('|')
      .map { |h| h.strip }
      .reject { |h| !h.include?('.') }

    hosts << GlobalSetting.hostname
    hosts << RailsMultisite::ConnectionManagement.current_hostname

  end

  def total_hosts_usage
    hosts = linked_hosts.clone
    whitelisted = whitelisted_spam_hosts

    hosts.reject! do |h|
      whitelisted.any? do |w|
        h.end_with?(w)
      end
    end

    return hosts if hosts.length == 0

    TopicLink.where(domain: hosts.keys, user_id: acting_user.id)
      .group(:domain, :post_id)
      .count
      .each_key do |tuple|
      domain = tuple[0]
      hosts[domain] = (hosts[domain] || 0) + 1
    end

    hosts
  end

  # Prevent new users from posting the same hosts too many times.
  def has_host_spam?
    return false if acting_user.present? && (acting_user.staged? || acting_user.mature_staged? || acting_user.has_trust_level?(TrustLevel[1]))
    return false if topic&.private_message?

    total_hosts_usage.values.any? { |count| count >= SiteSetting.newuser_spam_host_threshold }
  end

  def archetype
    topic&.archetype
  end

  def self.regular_order
    order(:sort_order, :post_number)
  end

  def self.reverse_order
    order('sort_order desc, post_number desc')
  end

  def self.summary(topic_id)
    topic_id = topic_id.to_i

    # percent rank has tons of ties
    where(topic_id: topic_id)
      .where([
        "id = ANY(
          (
            SELECT posts.id
            FROM posts
            WHERE posts.topic_id = #{topic_id.to_i}
            AND posts.post_number = 1
          ) UNION
          (
            SELECT p1.id
            FROM posts p1
            WHERE p1.percent_rank <= ?
            AND p1.topic_id = #{topic_id.to_i}
            ORDER BY p1.percent_rank
            LIMIT ?
          )
        )",
        SiteSetting.summary_percent_filter.to_f / 100.0,
        SiteSetting.summary_max_results
      ])
  end

  def update_flagged_posts_count
    PostAction.update_flagged_posts_count
  end

  def recover_public_post_actions
    PostAction.publics
      .with_deleted
      .where(post_id: self.id, id: self.custom_fields["deleted_public_actions"])
      .find_each do |post_action|
        post_action.recover!
        post_action.save!
      end

    self.custom_fields.delete("deleted_public_actions")
    self.save_custom_fields
  end

  def filter_quotes(parent_post = nil)
    return cooked if parent_post.blank?

    # We only filter quotes when there is exactly 1
    return cooked unless (quote_count == 1)

    parent_raw = parent_post.raw.sub(/\[quote.+\/quote\]/m, '')

    if raw[parent_raw] || (parent_raw.size < SHORT_POST_CHARS)
      return cooked.sub(/\<aside.+\<\/aside\>/m, '')
    end

    cooked
  end

  def external_id
    "#{topic_id}/#{post_number}"
  end

  def reply_to_post
    return if reply_to_post_number.blank?
    @reply_to_post ||= Post.find_by("topic_id = :topic_id AND post_number = :post_number", topic_id: topic_id, post_number: reply_to_post_number)
  end

  def reply_notification_target
    return if reply_to_post_number.blank?
    Post.find_by("topic_id = :topic_id AND post_number = :post_number AND user_id <> :user_id", topic_id: topic_id, post_number: reply_to_post_number, user_id: user_id).try(:user)
  end

  def self.excerpt(cooked, maxlength = nil, options = {})
    maxlength ||= SiteSetting.post_excerpt_maxlength
    PrettyText.excerpt(cooked, maxlength, options)
  end

  # Strip out most of the markup
  def excerpt(maxlength = nil, options = {})
    Post.excerpt(cooked, maxlength, options)
  end

  def excerpt_for_topic
    Post.excerpt(cooked, 220, strip_links: true, strip_images: true)
  end

  def is_first_post?
    post_number.blank? ?
      topic.try(:highest_post_number) == 0 :
      post_number == 1
  end

  def is_reply_by_email?
    via_email && post_number.present? && post_number > 1
  end

  def is_flagged?
    post_actions.where(post_action_type_id: PostActionType.flag_types_without_custom.values, deleted_at: nil).count != 0
  end

  def active_flags
    post_actions.active.where(post_action_type_id: PostActionType.flag_types_without_custom.values)
  end

  def has_active_flag?
    active_flags.count != 0
  end

  def unhide!
    self.update_attributes(hidden: false)
    self.topic.update_attributes(visible: true) if is_first_post?
    save(validate: false)
    publish_change_to_clients!(:acted)
  end

  def full_url
    "#{Discourse.base_url}#{url}"
  end

  def url(opts = nil)
    opts ||= {}

    if topic
      Post.url(topic.slug, topic.id, post_number, opts)
    else
      "/404"
    end
  end

  def unsubscribe_url(user)
    "#{Discourse.base_url}/email/unsubscribe/#{UnsubscribeKey.create_key_for(user, self)}"
  end

  def self.url(slug, topic_id, post_number, opts = nil)
    opts ||= {}

    result = "/t/"
    result << "#{slug}/" unless !!opts[:without_slug]

    "#{result}#{topic_id}/#{post_number}"
  end

  def self.urls(post_ids)
    ids = post_ids.map { |u| u }
    if ids.length > 0
      urls = {}
      Topic.joins(:posts).where('posts.id' => ids).
        select(['posts.id as post_id', 'post_number', 'topics.slug', 'topics.title', 'topics.id']).
        each do |t|
        urls[t.post_id.to_i] = url(t.slug, t.id, t.post_number)
      end
      urls
    else
      {}
    end
  end

  def revise(updated_by, changes = {}, opts = {})
    PostRevisor.new(self).revise!(updated_by, changes, opts)
  end

  def self.rebake_old(limit, priority: :normal, rate_limiter: true)

    limiter = RateLimiter.new(
      nil,
      "global_periodical_rebake_limit",
      GlobalSetting.max_old_rebakes_per_15_minutes,
      900,
      global: true
    )

    problems = []
    Post.where('baked_version IS NULL OR baked_version < ?', BAKED_VERSION)
      .order('id desc')
      .limit(limit).pluck(:id).each do |id|
      begin

        break if !limiter.can_perform?

        post = Post.find(id)
        post.rebake!(priority: priority)

        begin
          limiter.performed! if rate_limiter
        rescue RateLimiter::LimitExceeded
          break
        end

      rescue => e
        problems << { post: post, ex: e }

        attempts = post.custom_fields["rebake_attempts"].to_i

        if attempts > 3
          post.update_columns(baked_version: BAKED_VERSION)
          Discourse.warn_exception(e, message: "Can not rebake post# #{post.id} after 3 attempts, giving up")
        else
          post.custom_fields["rebake_attempts"] = attempts + 1
          post.save_custom_fields
        end

      end
    end
    problems
  end

  def rebake!(invalidate_broken_images: false, invalidate_oneboxes: false, priority: nil)
    new_cooked = cook(raw, topic_id: topic_id, invalidate_oneboxes: invalidate_oneboxes)
    old_cooked = cooked

    update_columns(cooked: new_cooked, baked_at: Time.new, baked_version: BAKED_VERSION)

    if invalidate_broken_images
      custom_fields.delete(BROKEN_IMAGES)
      save_custom_fields
    end

    # Extracts urls from the body
    TopicLink.extract_from(self)
    QuotedPost.extract_from(self)

    # make sure we trigger the post process
    trigger_post_process(bypass_bump: true, priority: priority)

    publish_change_to_clients!(:rebaked)

    new_cooked != old_cooked
  end

  def set_owner(new_user, actor, skip_revision = false)
    return if user_id == new_user.id

    edit_reason = I18n.t('change_owner.post_revision_text', locale: SiteSetting.default_locale)

    revise(
      actor,
      { raw: self.raw, user_id: new_user.id, edit_reason: edit_reason },
      bypass_bump: true, skip_revision: skip_revision, skip_validations: true
    )

    if post_number == topic.highest_post_number
      topic.update_columns(last_post_user_id: new_user.id)
    end
  end

  before_create do
    PostCreator.before_create_tasks(self)
  end

  def self.estimate_posts_per_day
    val = $redis.get("estimated_posts_per_day")
    return val.to_i if val

    posts_per_day = Topic.listable_topics.secured.joins(:posts).merge(Post.created_since(30.days.ago)).count / 30
    $redis.setex("estimated_posts_per_day", 1.day.to_i, posts_per_day.to_s)
    posts_per_day

  end

  # This calculates the geometric mean of the post timings and stores it along with
  # each post.
  def self.calculate_avg_time(min_topic_age = nil)
    retry_lock_error do
      builder = DB.build("UPDATE posts
                SET avg_time = (x.gmean / 1000)
                FROM (SELECT post_timings.topic_id,
                             post_timings.post_number,
                             round(exp(avg(CASE WHEN msecs > 0 THEN ln(msecs) ELSE 0 END))) AS gmean
                      FROM post_timings
                      INNER JOIN posts AS p2
                        ON p2.post_number = post_timings.post_number
                          AND p2.topic_id = post_timings.topic_id
                          AND p2.user_id <> post_timings.user_id
                      GROUP BY post_timings.topic_id, post_timings.post_number) AS x
                /*where*/")

      builder.where("x.topic_id = posts.topic_id
                  AND x.post_number = posts.post_number
                  AND (posts.avg_time <> (x.gmean / 1000)::int OR posts.avg_time IS NULL)")

      if min_topic_age
        builder.where("posts.topic_id IN (SELECT id FROM topics where bumped_at > :bumped_at)",
                     bumped_at: min_topic_age)
      end

      builder.exec
    end
  end

  before_save do
    self.last_editor_id ||= user_id

    if !new_record? && will_save_change_to_raw?
      self.cooked = cook(raw, topic_id: topic_id)
    end

    self.baked_at = Time.new
    self.baked_version = BAKED_VERSION
  end

  def advance_draft_sequence
    return if topic.blank? # could be deleted
    DraftSequence.next!(last_editor_id, topic.draft_key) if last_editor_id
  end

  # TODO: move to post-analyzer?
  # Determine what posts are quoted by this post
  def extract_quoted_post_numbers
    temp_collector = []

    # Create relationships for the quotes
    raw.scan(/\[quote=\"([^"]+)"\]/).each do |quote|
      args = parse_quote_into_arguments(quote)
      # If the topic attribute is present, ensure it's the same topic
      if !(args[:topic].present? && topic_id != args[:topic]) && args[:post] != post_number
        temp_collector << args[:post]
      end
    end

    temp_collector.uniq!
    self.quoted_post_numbers = temp_collector
    self.quote_count = temp_collector.size
  end

  def save_reply_relationships
    add_to_quoted_post_numbers(reply_to_post_number)
    return if self.quoted_post_numbers.blank?

    # Create a reply relationship between quoted posts and this new post
    self.quoted_post_numbers.each do |p|
      post = Post.find_by(topic_id: topic_id, post_number: p)
      create_reply_relationship_with(post)
    end
  end

  # Enqueue post processing for this post
  def trigger_post_process(bypass_bump: false, priority: :normal, new_post: false)
    args = {
      post_id: id,
      bypass_bump: bypass_bump,
      new_post: new_post,
    }
    args[:image_sizes] = image_sizes if image_sizes.present?
    args[:invalidate_oneboxes] = true if invalidate_oneboxes.present?
    args[:cooking_options] = self.cooking_options

    if priority && priority != :normal
      args[:queue] = priority.to_s
    end

    Jobs.enqueue(:process_post, args)
    DiscourseEvent.trigger(:after_trigger_post_process, self)
  end

  def self.public_posts_count_per_day(start_date, end_date, category_id = nil)
    result = public_posts.where('posts.created_at >= ? AND posts.created_at <= ?', start_date, end_date)
      .where(post_type: Post.types[:regular])
    result = result.where('topics.category_id = ?', category_id) if category_id
    result
      .group('date(posts.created_at)')
      .order('date(posts.created_at)')
      .count
  end

  def self.private_messages_count_per_day(start_date, end_date, topic_subtype)
    private_posts.with_topic_subtype(topic_subtype)
      .where('posts.created_at >= ? AND posts.created_at <= ?', start_date, end_date)
      .group('date(posts.created_at)')
      .order('date(posts.created_at)')
      .count
  end

  def reply_history(max_replies = 100, guardian = nil)
    post_ids = DB.query_single(<<~SQL, post_id: id, topic_id: topic_id)
    WITH RECURSIVE breadcrumb(id, reply_to_post_number) AS (
          SELECT p.id, p.reply_to_post_number FROM posts AS p
            WHERE p.id = :post_id
          UNION
             SELECT p.id, p.reply_to_post_number FROM posts AS p, breadcrumb
               WHERE breadcrumb.reply_to_post_number = p.post_number
                 AND p.topic_id = :topic_id
        )
    SELECT id from breadcrumb
    WHERE id <> :post_id
    ORDER by id
    SQL

    # [1,2,3][-10,-1] => nil
    post_ids = (post_ids[(0 - max_replies)..-1] || post_ids)

    Post.secured(guardian).where(id: post_ids).includes(:user, :topic).order(:id).to_a
  end

  MAX_REPLY_LEVEL ||= 1000

  def reply_ids(guardian = nil, only_replies_to_single_post: true)
    builder = DB.build(<<~SQL)
      WITH RECURSIVE breadcrumb(id, level) AS (
        SELECT :post_id, 0
        UNION
        SELECT reply_id, level + 1
        FROM post_replies AS r
          JOIN breadcrumb AS b ON (r.post_id = b.id)
        WHERE r.post_id <> r.reply_id
              AND b.level < :max_reply_level
      ), breadcrumb_with_count AS (
          SELECT
            id,
            level,
            COUNT(*) AS count
          FROM post_replies AS r
            JOIN breadcrumb AS b ON (r.reply_id = b.id)
          WHERE r.reply_id <> r.post_id
          GROUP BY id, level
      )
      SELECT id, level
      FROM breadcrumb_with_count
      /*where*/
      ORDER BY id
    SQL

    builder.where("level > 0")

    # ignore posts that aren't replies to exactly one post
    # for example it skips a post when it contains 2 quotes (which are replies) from different posts
    builder.where("count = 1") if only_replies_to_single_post

    replies = builder.query_hash(post_id: id, max_reply_level: MAX_REPLY_LEVEL)
    replies.each { |r| r.symbolize_keys! }

    secured_ids = Post.secured(guardian).where(id: replies.map { |r| r[:id] }).pluck(:id).to_set

    replies.reject { |r| !secured_ids.include?(r[:id]) }
  end

  def revert_to(number)
    return if number >= version
    post_revision = PostRevision.find_by(post_id: id, number: (number + 1))
    post_revision.modifications.each do |attribute, change|
      attribute = "version" if attribute == "cached_version"
      write_attribute(attribute, change[0])
    end
  end

  def self.rebake_all_quoted_posts(user_id)
    return if user_id.blank?

    DB.exec(<<~SQL, user_id)
      WITH user_quoted_posts AS (
        SELECT post_id
          FROM quoted_posts
         WHERE quoted_post_id IN (SELECT id FROM posts WHERE user_id = ?)
      )
      UPDATE posts
         SET baked_version = NULL
       WHERE baked_version IS NOT NULL
         AND id IN (SELECT post_id FROM user_quoted_posts)
    SQL
  end

  def seen?(user)
    PostTiming.where(topic_id: topic_id, post_number: post_number, user_id: user.id).exists?
  end

  def index_search
    SearchIndexer.index(self)
  end

  def create_user_action
    UserActionCreator.log_post(self)
  end

  def locked?
    locked_by_id.present?
  end

  def link_post_uploads(fragments: nil)
    upload_ids = []
    fragments ||= Nokogiri::HTML::fragment(self.cooked)

    fragments.css("a/@href", "img/@src").each do |media|
      if upload = Upload.get_from_url(media.value)
        upload_ids << upload.id
      end
    end

    upload_ids |= Upload.where(id: downloaded_images.values).pluck(:id)
    values = upload_ids.map! { |upload_id| "(#{self.id},#{upload_id})" }.join(",")

    PostUpload.transaction do
      PostUpload.where(post_id: self.id).delete_all

      if values.size > 0
        DB.exec("INSERT INTO post_uploads (post_id, upload_id) VALUES #{values}")
      end
    end
  end

  def downloaded_images
    JSON.parse(self.custom_fields[Post::DOWNLOADED_IMAGES].presence || "{}")
  rescue JSON::ParserError
    {}
  end

  private

  def parse_quote_into_arguments(quote)
    return {} unless quote.present?
    args = HashWithIndifferentAccess.new
    quote.first.scan(/([a-z]+)\:(\d+)/).each do |arg|
      args[arg[0]] = arg[1].to_i
    end
    args
  end

  def add_to_quoted_post_numbers(num)
    return unless num.present?
    self.quoted_post_numbers ||= []
    self.quoted_post_numbers << num
  end

  def create_reply_relationship_with(post)
    return if post.nil? || self.deleted_at.present?
    post_reply = post.post_replies.new(reply_id: id)
    if post_reply.save
      if Topic.visible_post_types.include?(self.post_type)
        Post.where(id: post.id).update_all ['reply_count = reply_count + 1']
      end
    end
  end

end

# == Schema Information
#
# Table name: posts
#
#  id                      :integer          not null, primary key
#  user_id                 :integer
#  topic_id                :integer          not null
#  post_number             :integer          not null
#  raw                     :text             not null
#  cooked                  :text             not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  reply_to_post_number    :integer
#  reply_count             :integer          default(0), not null
#  quote_count             :integer          default(0), not null
#  deleted_at              :datetime
#  off_topic_count         :integer          default(0), not null
#  like_count              :integer          default(0), not null
#  incoming_link_count     :integer          default(0), not null
#  bookmark_count          :integer          default(0), not null
#  avg_time                :integer
#  score                   :float
#  reads                   :integer          default(0), not null
#  post_type               :integer          default(1), not null
#  sort_order              :integer
#  last_editor_id          :integer
#  hidden                  :boolean          default(FALSE), not null
#  hidden_reason_id        :integer
#  notify_moderators_count :integer          default(0), not null
#  spam_count              :integer          default(0), not null
#  illegal_count           :integer          default(0), not null
#  inappropriate_count     :integer          default(0), not null
#  last_version_at         :datetime         not null
#  user_deleted            :boolean          default(FALSE), not null
#  reply_to_user_id        :integer
#  percent_rank            :float            default(1.0)
#  notify_user_count       :integer          default(0), not null
#  like_score              :integer          default(0), not null
#  deleted_by_id           :integer
#  edit_reason             :string
#  word_count              :integer
#  version                 :integer          default(1), not null
#  cook_method             :integer          default(1), not null
#  wiki                    :boolean          default(FALSE), not null
#  baked_at                :datetime
#  baked_version           :integer
#  hidden_at               :datetime
#  self_edits              :integer          default(0), not null
#  reply_quoted            :boolean          default(FALSE), not null
#  via_email               :boolean          default(FALSE), not null
#  raw_email               :text
#  public_version          :integer          default(1), not null
#  action_code             :string
#  image_url               :string
#  locked_by_id            :integer
#
# Indexes
#
#  idx_posts_created_at_topic_id             (created_at,topic_id) WHERE (deleted_at IS NULL)
#  idx_posts_deleted_posts                   (topic_id,post_number) WHERE (deleted_at IS NOT NULL)
#  idx_posts_user_id_deleted_at              (user_id) WHERE (deleted_at IS NULL)
#  index_posts_on_reply_to_post_number       (reply_to_post_number)
#  index_posts_on_topic_id_and_percent_rank  (topic_id,percent_rank)
#  index_posts_on_topic_id_and_post_number   (topic_id,post_number) UNIQUE
#  index_posts_on_topic_id_and_sort_order    (topic_id,sort_order)
#  index_posts_on_user_id_and_created_at     (user_id,created_at)
#
