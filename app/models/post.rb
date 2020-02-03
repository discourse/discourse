# frozen_string_literal: true

require 'archetype'
require 'digest/sha1'

class Post < ActiveRecord::Base
  include RateLimiter::OnCreateRecord
  include Trashable
  include Searchable
  include HasCustomFields
  include LimitedEdit

  cattr_accessor :plugin_permitted_create_params
  self.plugin_permitted_create_params = {}

  # increase this number to force a system wide post rebake
  # Recreate `index_for_rebake_old` when the number is increased
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

  validates_with PostValidator, unless: :skip_validation

  after_save :index_search

  # We can pass several creating options to a post via attributes
  attr_accessor :image_sizes, :quoted_post_numbers, :no_bump, :invalidate_oneboxes, :cooking_options, :skip_unique_check, :skip_validation

  LARGE_IMAGES            ||= "large_images"
  BROKEN_IMAGES           ||= "broken_images"
  DOWNLOADED_IMAGES       ||= "downloaded_images"
  MISSING_UPLOADS         ||= "missing uploads"
  MISSING_UPLOADS_IGNORED ||= "missing uploads ignored"
  NOTICE_TYPE             ||= "notice_type"
  NOTICE_ARGS             ||= "notice_args"

  SHORT_POST_CHARS ||= 1200

  register_custom_field_type(MISSING_UPLOADS, :json)
  register_custom_field_type(MISSING_UPLOADS_IGNORED, :boolean)

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
      .joins("INNER JOIN (#{Topic.for_digest(user, Time.at(0)).select(:id).to_sql}) AS digest_topics ON digest_topics.id = posts.topic_id") # we want all topics with new content, regardless when they were created
      .order('posts.created_at ASC')

    q = q.where.not(post_type: Post.types[:whisper]) unless user.staff?
    q
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

  scope :have_uploads, -> {
    where("
          (
            posts.cooked LIKE '%<a %' OR
            posts.cooked LIKE '%<img %' OR
            posts.cooked LIKE '%<video %'
          ) AND (
            posts.cooked LIKE ? OR
            posts.cooked LIKE '%/original/%' OR
            posts.cooked LIKE '%/optimized/%' OR
            posts.cooked LIKE '%data-orig-src=%' OR
            posts.cooked LIKE '%/uploads/short-url/%'
          )", "%/uploads/#{RailsMultisite::ConnectionManagement.current_db}/%"
        )
  }

  delegate :username, to: :user

  def self.hidden_reasons
    @hidden_reasons ||= Enum.new(flag_threshold_reached: 1,
                                 flag_threshold_reached_again: 2,
                                 new_user_spam_threshold_reached: 3,
                                 flagged_by_tl3_user: 4,
                                 email_spam_header_found: 5,
                                 flagged_by_tl4_user: 6,
                                 email_authentication_result_header: 7)
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

  def self.notices
    @notices ||= Enum.new(custom: "custom",
                          new_user: "new_user",
                          returning_user: "returning_user")
  end

  def self.find_by_detail(key, value)
    includes(:post_details).find_by(post_details: { key: key, value: value })
  end

  def self.excerpt_size=(sz)
    @excerpt_size = sz
  end

  def self.excerpt_size
    @excerpt_size || 220
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

  def readers_count
    read_count = reads - 1 # Excludes poster
    read_count < 0 ? 0 : read_count
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
    self.delete_post_notices
    super(trashed_by)
  end

  def recover!
    super
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
      Discourse.redis.setex(unique_post_key, SiteSetting.unique_posts_mins.minutes.to_i, id)
    end
  end

  def matches_recent_post?
    post_id = Discourse.redis.get(unique_post_key)
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
      post_analyzer.public_send(attr)
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

    if self.with_secure_media?
      each_upload_url do |url|
        uri = URI.parse(url)
        if FileHelper.is_supported_media?(File.basename(uri.path))
          raw = raw.sub(Discourse.store.s3_upload_host, "#{Discourse.base_url}/#{Upload::SECURE_MEDIA_ROUTE}")
        end
      end
    end

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

  def delete_post_notices
    self.custom_fields.delete(Post::NOTICE_TYPE)
    self.custom_fields.delete(Post::NOTICE_ARGS)
    self.save_custom_fields
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
    Post.excerpt(cooked, maxlength, options.merge(post: self))
  end

  def excerpt_for_topic
    Post.excerpt(cooked, Post.excerpt_size, strip_links: true, strip_images: true, post: self)
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

  def reviewable_flag
    ReviewableFlaggedPost.pending.find_by(target: self)
  end

  def with_secure_media?
    return false if !SiteSetting.secure_media?
    SiteSetting.login_required? || \
      (topic.present? && (topic.private_message? || topic.category&.read_restricted))
  end

  def hide!(post_action_type_id, reason = nil)
    return if hidden?

    reason ||= hidden_at ?
      Post.hidden_reasons[:flag_threshold_reached_again] :
      Post.hidden_reasons[:flag_threshold_reached]

    hiding_again = hidden_at.present?

    self.hidden = true
    self.hidden_at = Time.zone.now
    self.hidden_reason_id = reason
    save!

    Topic.where(
      "id = :topic_id AND NOT EXISTS(SELECT 1 FROM POSTS WHERE topic_id = :topic_id AND NOT hidden)",
      topic_id: topic_id
    ).update_all(visible: false)

    # inform user
    if user.present?
      options = {
        url: url,
        edit_delay: SiteSetting.cooldown_minutes_after_hiding_posts,
        flag_reason: I18n.t(
          "flag_reasons.#{PostActionType.types[post_action_type_id]}",
          locale: SiteSetting.default_locale,
          base_path: Discourse.base_path
        )
      }

      Jobs.enqueue_in(
        5.seconds,
        :send_system_message,
        user_id: user.id,
        message_type: hiding_again ? :post_hidden_again : :post_hidden,
        message_options: options
      )
    end
  end

  def unhide!
    self.update(hidden: false)
    self.topic.update(visible: true) if is_first_post?
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

    result = +"/t/"
    result << "#{slug}/" if !opts[:without_slug]

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

    update_columns(
      cooked: new_cooked,
      baked_at: Time.zone.now,
      baked_version: BAKED_VERSION
    )

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
    val = Discourse.redis.get("estimated_posts_per_day")
    return val.to_i if val

    posts_per_day = Topic.listable_topics.secured.joins(:posts).merge(Post.created_since(30.days.ago)).count / 30
    Discourse.redis.setex("estimated_posts_per_day", 1.day.to_i, posts_per_day.to_s)
    posts_per_day

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
        SELECT reply_post_id, level + 1
        FROM post_replies AS r
          JOIN posts AS p ON p.id = reply_post_id
          JOIN breadcrumb AS b ON (r.post_id = b.id)
        WHERE r.post_id <> r.reply_post_id
          AND b.level < :max_reply_level
          AND p.topic_id = :topic_id
      ), breadcrumb_with_count AS (
          SELECT
            id,
            level,
            COUNT(*) AS count
          FROM post_replies AS r
            JOIN breadcrumb AS b ON (r.reply_post_id = b.id)
          WHERE r.reply_post_id <> r.post_id
          GROUP BY id, level
      )
      SELECT id, MIN(level) AS level
      FROM breadcrumb_with_count
      /*where*/
      GROUP BY id
      ORDER BY id
    SQL

    builder.where("level > 0")

    # ignore posts that aren't replies to exactly one post
    # for example it skips a post when it contains 2 quotes (which are replies) from different posts
    builder.where("count = 1") if only_replies_to_single_post

    replies = builder.query_hash(post_id: id, max_reply_level: MAX_REPLY_LEVEL, topic_id: topic_id)
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

  def locked?
    locked_by_id.present?
  end

  def link_post_uploads(fragments: nil)
    upload_ids = []

    each_upload_url(fragments: fragments) do |src, _, sha1|
      upload = nil
      upload = Upload.find_by(sha1: sha1) if sha1.present?
      upload ||= Upload.get_from_url(src)
      upload_ids << upload.id if upload.present?
    end

    upload_ids |= Upload.where(id: downloaded_images.values).pluck(:id)
    post_uploads = upload_ids.map do |upload_id|
      { post_id: self.id, upload_id: upload_id }
    end

    PostUpload.transaction do
      PostUpload.where(post_id: self.id).delete_all

      if post_uploads.size > 0
        PostUpload.insert_all(post_uploads)
      end

      if SiteSetting.secure_media?
        Upload.where(id: upload_ids, access_control_post_id: nil).update_all(
          access_control_post_id: self.id
        )
      end
    end
  end

  def update_uploads_secure_status
    if Discourse.store.external?
      self.uploads.each { |upload| upload.update_secure_status }
    end
  end

  def downloaded_images
    JSON.parse(self.custom_fields[Post::DOWNLOADED_IMAGES].presence || "{}")
  rescue JSON::ParserError
    {}
  end

  def each_upload_url(fragments: nil, include_local_upload: true)
    current_db = RailsMultisite::ConnectionManagement.current_db
    upload_patterns = [
      /\/uploads\/#{current_db}\//,
      /\/original\//,
      /\/optimized\//,
      /\/uploads\/short-url\/[a-zA-Z0-9]+(\.[a-z0-9]+)?/
    ]

    fragments ||= Nokogiri::HTML::fragment(self.cooked)

    links = fragments.css("a/@href", "img/@src").map do |media|
      src = media.value
      next if src.blank?

      if src.end_with?("/images/transparent.png") && (parent = media.parent)["data-orig-src"].present?
        parent["data-orig-src"]
      else
        src
      end
    end.compact.uniq

    links.each do |src|
      src = src.split("?")[0]

      if src.start_with?("upload://")
        sha1 = Upload.sha1_from_short_url(src)
        yield(src, nil, sha1)
        next
      elsif src.include?("/uploads/short-url/")
        sha1 = Upload.sha1_from_short_path(src)
        yield(src, nil, sha1)
        next
      end

      next if upload_patterns.none? { |pattern| src =~ pattern }
      next if Rails.configuration.multisite && src.exclude?(current_db)

      src = "#{SiteSetting.force_https ? "https" : "http"}:#{src}" if src.start_with?("//")
      next unless Discourse.store.has_been_uploaded?(src) || (include_local_upload && src =~ /\A\/[^\/]/i)

      path = begin
        URI(UrlHelper.unencode(GlobalSetting.cdn_url ? src.sub(GlobalSetting.cdn_url, "") : src))&.path
      rescue URI::Error
      end

      next if path.blank?

      sha1 =
        if path.include? "optimized"
          OptimizedImage.extract_sha1(path)
        else
          Upload.extract_sha1(path) || Upload.sha1_from_short_path(path)
        end

      yield(src, path, sha1)
    end
  end

  def self.find_missing_uploads(include_local_upload: true)
    missing_uploads = []
    missing_post_uploads = {}
    count = 0

    DistributedMutex.synchronize("find_missing_uploads", validity: 30.minutes) do
      PostCustomField.where(name: Post::MISSING_UPLOADS).delete_all
      query = Post
        .have_uploads
        .joins(:topic)
        .joins("LEFT JOIN post_custom_fields ON posts.id = post_custom_fields.post_id AND post_custom_fields.name = '#{Post::MISSING_UPLOADS_IGNORED}'")
        .where("post_custom_fields.id IS NULL")
        .select(:id, :cooked)

      query.find_in_batches do |posts|
        ids = posts.pluck(:id)
        sha1s = Upload.joins(:post_uploads).where("post_uploads.post_id >= ? AND post_uploads.post_id <= ?", ids.min, ids.max).pluck(:sha1)

        posts.each do |post|
          post.each_upload_url do |src, path, sha1|
            next if sha1.present? && sha1s.include?(sha1)

            missing_post_uploads[post.id] ||= []

            if missing_uploads.include?(src)
              missing_post_uploads[post.id] << src
              next
            end

            upload_id = nil
            upload_id = Upload.where(sha1: sha1).pluck_first(:id) if sha1.present?
            upload_id ||= yield(post, src, path, sha1)

            if upload_id.blank?
              missing_uploads << src
              missing_post_uploads[post.id] << src
            end
          end
        end
      end

      missing_post_uploads = missing_post_uploads.reject do |post_id, uploads|
        if uploads.present?
          PostCustomField.create!(post_id: post_id, name: Post::MISSING_UPLOADS, value: uploads.to_json)
          count += uploads.count
        end

        uploads.empty?
      end
    end

    { uploads: missing_uploads, post_uploads: missing_post_uploads, count: count }
  end

  def owned_uploads_via_access_control
    Upload.where(access_control_post_id: self.id)
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
    post_reply = post.post_replies.new(reply_post_id: id)
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
#  index_for_rebake_old                      (id) WHERE (((baked_version IS NULL) OR (baked_version < 2)) AND (deleted_at IS NULL))
#  index_posts_on_id_and_baked_version       (id DESC,baked_version) WHERE (deleted_at IS NULL)
#  index_posts_on_reply_to_post_number       (reply_to_post_number)
#  index_posts_on_topic_id_and_percent_rank  (topic_id,percent_rank)
#  index_posts_on_topic_id_and_post_number   (topic_id,post_number) UNIQUE
#  index_posts_on_topic_id_and_sort_order    (topic_id,sort_order)
#  index_posts_on_user_id_and_created_at     (user_id,created_at)
#
