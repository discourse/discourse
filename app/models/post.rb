# frozen_string_literal: true

require "archetype"
require "digest/sha1"

class Post < ActiveRecord::Base
  include RateLimiter::OnCreateRecord
  include Trashable
  include Searchable
  include HasCustomFields
  include LimitedEdit

  self.ignored_columns = [
    "avg_time", # TODO: Remove when 20240212034010_drop_deprecated_columns has been promoted to pre-deploy
    "image_url", # TODO: Remove when 20240212034010_drop_deprecated_columns has been promoted to pre-deploy
  ]

  cattr_accessor :plugin_permitted_create_params, :plugin_permitted_update_params
  self.plugin_permitted_create_params = {}
  self.plugin_permitted_update_params = {}

  # increase this number to force a system wide post rebake
  # Recreate `index_for_rebake_old` when the number is increased
  # Version 1, was the initial version
  # Version 2 15-12-2017, introduces CommonMark and a huge number of onebox fixes
  BAKED_VERSION = 2

  # Time between the delete and permanent delete of a post
  PERMANENT_DELETE_TIMER = 5.minutes

  rate_limit
  rate_limit :limit_posts_per_day

  belongs_to :user
  belongs_to :topic

  belongs_to :reply_to_user, class_name: "User"

  has_many :post_replies
  has_many :replies, through: :post_replies
  has_many :post_actions, dependent: :destroy
  has_many :topic_links
  has_many :group_mentions, dependent: :destroy

  has_many :upload_references, as: :target, dependent: :destroy
  has_many :uploads, through: :upload_references

  has_one :post_stat

  has_many :bookmarks, as: :bookmarkable

  has_one :incoming_email

  has_many :post_details

  has_many :post_revisions
  has_many :revisions, -> { order(:number) }, foreign_key: :post_id, class_name: "PostRevision"

  has_many :moved_posts_as_old_post,
           class_name: "MovedPost",
           foreign_key: :old_post_id,
           dependent: :destroy
  has_many :moved_posts_as_new_post,
           class_name: "MovedPost",
           foreign_key: :new_post_id,
           dependent: :destroy

  has_many :user_actions, foreign_key: :target_post_id

  has_many :user_badges,
           -> { for_post_header_badges },
           foreign_key: :post_id,
           class_name: "UserBadge"

  belongs_to :image_upload, class_name: "Upload"

  has_many :post_hotlinked_media, dependent: :destroy, class_name: "PostHotlinkedMedia"
  has_many :reviewables, as: :target, dependent: :destroy

  validates_with PostValidator, unless: :skip_validation
  validates :edit_reason, length: { maximum: 1000 }

  after_commit :index_search

  # We can pass several creating options to a post via attributes
  attr_accessor :image_sizes,
                :quoted_post_numbers,
                :no_bump,
                :invalidate_oneboxes,
                :cooking_options,
                :skip_unique_check,
                :skip_validation

  MISSING_UPLOADS = "missing uploads"
  MISSING_UPLOADS_IGNORED = "missing uploads ignored"
  NOTICE = "notice"

  SHORT_POST_CHARS = 1200

  register_custom_field_type(MISSING_UPLOADS, :json)
  register_custom_field_type(MISSING_UPLOADS_IGNORED, :boolean)

  register_custom_field_type(NOTICE, :json)

  scope :private_posts_for_user,
        ->(user) do
          where(
            "topics.id IN (#{Topic::PRIVATE_MESSAGES_SQL_USER})
      OR topics.id IN (#{Topic::PRIVATE_MESSAGES_SQL_GROUP})",
            user_id: user.id,
          )
        end

  scope :by_newest, -> { order("created_at DESC, id DESC") }
  scope :by_post_number, -> { order("post_number ASC") }
  scope :with_user, -> { includes(:user) }
  scope :created_since, ->(time_ago) { where("posts.created_at > ?", time_ago) }
  scope :public_posts,
        -> { joins(:topic).where("topics.archetype <> ?", Archetype.private_message) }
  scope :private_posts,
        -> { joins(:topic).where("topics.archetype = ?", Archetype.private_message) }
  scope :with_topic_subtype, ->(subtype) { joins(:topic).where("topics.subtype = ?", subtype) }
  scope :visible, -> { joins(:topic).where("topics.visible = true").where(hidden: false) }
  scope :secured,
        ->(guardian) { where("posts.post_type IN (?)", Topic.visible_post_types(guardian&.user)) }

  scope :for_mailing_list,
        ->(user, since) do
          q =
            created_since(since).joins(
              "INNER JOIN (#{Topic.for_digest(user, Time.at(0)).select(:id).to_sql}) AS digest_topics ON digest_topics.id = posts.topic_id",
            ) # we want all topics with new content, regardless when they were created
              .order("posts.created_at ASC")

          q = q.where.not(post_type: Post.types[:whisper]) unless user.staff?
          q
        end

  scope :raw_match,
        ->(pattern, type = "string") do
          type = type&.downcase

          case type
          when "string"
            where("raw ILIKE ?", "%#{pattern}%")
          when "regex"
            where("raw ~* ?", "(?n)#{pattern}")
          end
        end

  scope :have_uploads,
        -> do
          where(
            "
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
          )",
            "%/uploads/#{RailsMultisite::ConnectionManagement.current_db}/%",
          )
        end

  delegate :username, to: :user

  def self.hidden_reasons
    @hidden_reasons ||=
      Enum.new(
        flag_threshold_reached: 1,
        flag_threshold_reached_again: 2,
        new_user_spam_threshold_reached: 3,
        flagged_by_tl3_user: 4,
        email_spam_header_found: 5,
        flagged_by_tl4_user: 6,
        email_authentication_result_header: 7,
        imported_as_unlisted: 8,
      )
  end

  def self.types
    @types ||= Enum.new(regular: 1, moderator_action: 2, small_action: 3, whisper: 4)
  end

  def self.cook_methods
    @cook_methods ||= Enum.new(regular: 1, raw_html: 2, email: 3)
  end

  def self.notices
    @notices ||= Enum.new(custom: "custom", new_user: "new_user", returning_user: "returning_user")
  end

  def self.find_by_detail(key, value)
    includes(:post_details).find_by(post_details: { key: key, value: value })
  end

  def self.find_by_number(topic_id, post_number)
    find_by(topic_id: topic_id, post_number: post_number)
  end

  def whisper?
    post_type == Post.types[:whisper]
  end

  def add_detail(key, value, extra = nil)
    post_details.build(key: key, value: value, extra: extra)
  end

  def limit_posts_per_day
    if user && user.new_user_posting_on_first_day? && post_number && post_number > 1
      RateLimiter.new(
        user,
        "first-day-replies-per-day",
        SiteSetting.max_replies_in_first_day,
        1.day.to_i,
      )
    end
  end

  def badges_granted
    user_badges.select { |user_badge| user_badge.user_id == user_id }
  end

  def readers_count
    read_count = reads - 1 # Excludes poster
    read_count < 0 ? 0 : read_count
  end

  def publish_change_to_clients!(type, opts = {})
    # special failsafe for posts missing topics consistency checks should fix,
    # but message is safe to skip
    return unless topic

    skip_topic_stats = opts.delete(:skip_topic_stats)

    message = {
      id: id,
      post_number: post_number,
      updated_at: Time.now,
      user_id: user_id,
      last_editor_id: last_editor_id,
      type: type,
      version: version,
    }.merge(opts)

    publish_message!("/topic/#{topic_id}", message)
    Topic.publish_stats_to_clients!(topic.id, type) unless skip_topic_stats
  end

  def publish_message!(channel, message, opts = {})
    return unless topic

    if Topic.visible_post_types.include?(post_type)
      opts.merge!(topic.secure_audience_publish_messages)
    else
      opts[:user_ids] = User.human_users.where("admin OR moderator OR id = ?", user_id).pluck(:id)
    end

    MessageBus.publish(channel, message, opts) if opts[:user_ids] != [] && opts[:group_ids] != []
  end

  def trash!(trashed_by = nil)
    self.topic_links.each(&:destroy)
    self.save_custom_fields if self.custom_fields.delete(Post::NOTICE)
    super(trashed_by)
  end

  def recover!
    super
    recover_public_post_actions
    TopicLink.extract_from(self)
    QuotedPost.extract_from(self)
    topic.category.update_latest if topic && topic.category_id && topic.category
  end

  # The key we use in redis to ensure unique posts
  def unique_post_key
    "unique#{topic&.private_message? ? "-pm" : ""}-post-#{user_id}:#{raw_hash}"
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

  def self.allowed_image_classes
    @allowed_image_classes ||= %w[avatar favicon thumbnail emoji ytp-thumbnail-image]
  end

  def post_analyzer
    @post_analyzers ||= {}
    @post_analyzers[raw_hash] ||= PostAnalyzer.new(raw, topic_id)
  end

  %w[
    raw_mentions
    linked_hosts
    embedded_media_count
    attachment_count
    link_count
    raw_links
    has_oneboxes?
  ].each { |attr| define_method(attr) { post_analyzer.public_send(attr) } }

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

    # A rule in our Markdown pipeline may have Guardian checks that require a
    # user to be present. The last editing user of the post will be more
    # generally up to date than the creating user. For example, we use
    # this when cooking #hashtags to determine whether we should render
    # the found hashtag based on whether the user can access the category it
    # is referencing.
    options[:user_id] = self.last_editor_id
    options[:omit_nofollow] = true if omit_nofollow?
    options[:post_id] = self.id

    if self.should_secure_uploads?
      each_upload_url do |url|
        uri = URI.parse(url)
        if FileHelper.is_supported_media?(File.basename(uri.path))
          raw =
            raw.sub(
              url,
              Rails.application.routes.url_for(
                controller: "uploads",
                action: "show_secure",
                path: uri.path[1..-1],
                host: Discourse.current_hostname,
              ),
            )
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

  def allowed_spam_hosts
    hosts =
      SiteSetting
        .allowed_spam_host_domains
        .split("|")
        .map { |h| h.strip }
        .reject { |h| !h.include?(".") }

    hosts << GlobalSetting.hostname
    hosts << RailsMultisite::ConnectionManagement.current_hostname
  end

  def total_hosts_usage
    hosts = linked_hosts.clone
    allowlisted = allowed_spam_hosts

    hosts.reject! { |h| allowlisted.any? { |w| h.end_with?(w) } }

    return hosts if hosts.length == 0

    TopicLink
      .where(domain: hosts.keys, user_id: acting_user.id)
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
    if acting_user.present? &&
         (
           acting_user.staged? || acting_user.mature_staged? ||
             acting_user.has_trust_level?(TrustLevel[1])
         )
      return false
    end
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
    order("sort_order desc, post_number desc")
  end

  def self.summary(topic_id)
    topic_id = topic_id.to_i

    # percent rank has tons of ties
    where(topic_id: topic_id).where(
      [
        "posts.id = ANY(
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
        SiteSetting.summary_max_results,
      ],
    )
  end

  def delete_post_notices
    self.custom_fields.delete(Post::NOTICE)
    self.save_custom_fields
  end

  def recover_public_post_actions
    PostAction
      .publics
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

    parent_raw = parent_post.raw.sub(%r{\[quote.+/quote\]}m, "")

    if raw[parent_raw] || (parent_raw.size < SHORT_POST_CHARS)
      return cooked.sub(%r{\<aside.+\</aside\>}m, "")
    end

    cooked
  end

  def external_id
    "#{topic_id}/#{post_number}"
  end

  def reply_to_post
    return if reply_to_post_number.blank?
    @reply_to_post ||=
      Post.find_by(
        "topic_id = :topic_id AND post_number = :post_number",
        topic_id: topic_id,
        post_number: reply_to_post_number,
      )
  end

  def reply_notification_target
    return if reply_to_post_number.blank?
    Post.find_by(
      "topic_id = :topic_id AND post_number = :post_number AND user_id <> :user_id",
      topic_id: topic_id,
      post_number: reply_to_post_number,
      user_id: user_id,
    ).try(:user)
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
    Post.excerpt(
      cooked,
      SiteSetting.topic_excerpt_maxlength,
      strip_links: true,
      strip_images: true,
      post: self,
    )
  end

  def is_first_post?
    post_number.blank? ? topic.try(:highest_post_number) == 0 : post_number == 1
  end

  def is_category_description?
    topic.present? && topic.is_category_topic? && is_first_post?
  end

  def is_reply_by_email?
    via_email && post_number.present? && post_number > 1
  end

  def is_flagged?
    flags.count != 0
  end

  def post_action_type_view
    @post_action_type_view ||= PostActionTypeView.new
  end

  def flags
    post_actions.where(
      post_action_type_id: post_action_type_view.flag_types_without_additional_message.values,
      deleted_at: nil,
    )
  end

  def reviewable_flag
    ReviewableFlaggedPost.pending.find_by(target: self)
  end

  # NOTE (martin): This is turning into hack city; when changing this also
  # consider how it interacts with UploadSecurity and the uploads.rake tasks.
  def should_secure_uploads?
    return false if !SiteSetting.secure_uploads?
    topic_including_deleted = Topic.with_deleted.find_by(id: self.topic_id)
    return false if topic_including_deleted.blank?

    # NOTE: This is to be used for plugins where adding a new public upload
    # type that should not be secured via UploadSecurity.register_custom_public_type
    # is not an option. This also is not taken into account in the secure upload
    # rake tasks, and will more than likely change in future.
    modifier_result =
      DiscoursePluginRegistry.apply_modifier(
        :post_should_secure_uploads?,
        nil,
        self,
        topic_including_deleted,
      )
    return modifier_result if !modifier_result.nil?

    # NOTE: This is meant to be a stopgap solution to prevent secure uploads
    # in a single place (private messages) for sensitive admin data exports.
    # Ideally we would want a more comprehensive way of saying that certain
    # upload types get secured which is a hybrid/mixed mode secure uploads,
    # but for now this will do the trick.
    return topic_including_deleted.private_message? if SiteSetting.secure_uploads_pm_only?

    SiteSetting.login_required? || topic_including_deleted.private_message? ||
      topic_including_deleted.read_restricted_category?
  end

  def hide!(post_action_type_id, reason = nil, custom_message: nil)
    return if hidden?

    reason ||=
      (
        if hidden_at
          Post.hidden_reasons[:flag_threshold_reached_again]
        else
          Post.hidden_reasons[:flag_threshold_reached]
        end
      )

    hiding_again = hidden_at.present?

    Post.transaction do
      self.skip_validation = true
      should_update_user_stat = true

      update!(hidden: true, hidden_at: Time.zone.now, hidden_reason_id: reason)

      any_visible_posts_in_topic =
        Post.exists?(topic_id: topic_id, hidden: false, post_type: Post.types[:regular])

      if !any_visible_posts_in_topic
        self.topic.update_status(
          "visible",
          false,
          Discourse.system_user,
          { visibility_reason_id: Topic.visibility_reasons[:op_flag_threshold_reached] },
        )
        should_update_user_stat = false
      end

      # We need to do this because TopicStatusUpdater also does the decrement
      # and we don't want to double count for the OP.
      UserStatCountUpdater.decrement!(self) if should_update_user_stat
    end

    # inform user
    if user.present?
      options = {
        url: url,
        edit_delay: SiteSetting.cooldown_minutes_after_hiding_posts,
        flag_reason:
          I18n.t(
            "flag_reasons.#{post_action_type_view.types[post_action_type_id]}",
            locale: SiteSetting.default_locale,
            base_path: Discourse.base_path,
          ),
      }

      message = custom_message
      message = hiding_again ? :post_hidden_again : :post_hidden if message.nil?

      Jobs.enqueue_in(
        5.seconds,
        :send_system_message,
        user_id: user.id,
        message_type: message.to_s,
        message_options: options,
      )
    end
  end

  def unhide!
    Post.transaction do
      self.update!(hidden: false)
      should_update_user_stat = true

      # NOTE: We have to consider `nil` a valid reason here because historically
      # topics didn't have a visibility_reason_id, if we didn't do this we would
      # break backwards compat since we cannot backfill data.
      hidden_because_of_op_flagging =
        self.topic.visibility_reason_id == Topic.visibility_reasons[:op_flag_threshold_reached] ||
          self.topic.visibility_reason_id.nil?

      if is_first_post? && hidden_because_of_op_flagging
        self.topic.update_status(
          "visible",
          true,
          Discourse.system_user,
          { visibility_reason_id: Topic.visibility_reasons[:op_unhidden] },
        )
        should_update_user_stat = false
      end

      # We need to do this because TopicStatusUpdater also does the increment
      # and we don't want to double count for the OP.
      UserStatCountUpdater.increment!(self) if should_update_user_stat

      save(validate: false)
    end

    publish_change_to_clients!(:acted)
  end

  def full_url(opts = {})
    "#{Discourse.base_url}#{url(opts)}"
  end

  def relative_url(opts = {})
    "#{Discourse.base_path}#{url(opts)}"
  end

  def url(opts = nil)
    opts ||= {}

    if topic
      Post.url(topic.slug, topic.id, post_number, opts)
    else
      "/404"
    end
  end

  def canonical_url
    topic_view = TopicView.new(topic, nil, post_number: post_number)

    page = ""

    page = "?page=#{topic_view.page}" if topic_view.page > 1

    "#{topic.url}#{page}#post_#{post_number}"
  end

  def unsubscribe_url(user)
    key_value = UnsubscribeKey.create_key_for(user, UnsubscribeKey::TOPIC_TYPE, post: self)

    "#{Discourse.base_url}/email/unsubscribe/#{key_value}"
  end

  def self.url(slug, topic_id, post_number, opts = nil)
    opts ||= {}

    result = +"/t/"
    result << "#{slug}/" if !opts[:without_slug]

    if post_number == 1 && opts[:share_url]
      "#{result}#{topic_id}"
    else
      "#{result}#{topic_id}/#{post_number}"
    end
  end

  def self.urls(post_ids)
    ids = post_ids.map { |u| u }
    if ids.length > 0
      urls = {}
      Topic
        .joins(:posts)
        .where("posts.id" => ids)
        .select(["posts.id as post_id", "post_number", "topics.slug", "topics.title", "topics.id"])
        .each { |t| urls[t.post_id.to_i] = url(t.slug, t.id, t.post_number) }
      urls
    else
      {}
    end
  end

  def revise(updated_by, changes = {}, opts = {})
    PostRevisor.new(self).revise!(updated_by, changes, opts)
  end

  def self.rebake_old(limit, priority: :normal, rate_limiter: true)
    limiter =
      RateLimiter.new(
        nil,
        "global_periodical_rebake_limit",
        GlobalSetting.max_old_rebakes_per_15_minutes,
        900,
        global: true,
      )

    problems = []
    Post
      .where("baked_version IS NULL OR baked_version < ?", BAKED_VERSION)
      .order("id desc")
      .limit(limit)
      .pluck(:id)
      .each do |id|
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
            Discourse.warn_exception(
              e,
              message: "Can not rebake post# #{post.id} after 3 attempts, giving up",
            )
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

    update_columns(cooked: new_cooked, baked_at: Time.zone.now, baked_version: BAKED_VERSION)

    topic&.update_excerpt(excerpt_for_topic) if is_first_post?

    if invalidate_broken_images
      post_hotlinked_media.download_failed.destroy_all
      post_hotlinked_media.upload_create_failed.destroy_all
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

    edit_reason = I18n.t("change_owner.post_revision_text", locale: SiteSetting.default_locale)

    revise(
      actor,
      { raw: self.raw, user_id: new_user.id, edit_reason: edit_reason },
      bypass_bump: true,
      skip_revision: skip_revision,
      skip_validations: true,
    )

    topic.update_columns(last_post_user_id: new_user.id) if post_number == topic.highest_post_number
  end

  before_create { PostCreator.before_create_tasks(self) }

  def self.estimate_posts_per_day
    val = Discourse.redis.get("estimated_posts_per_day")
    return val.to_i if val

    posts_per_day =
      Topic.listable_topics.secured.joins(:posts).merge(Post.created_since(30.days.ago)).count / 30
    Discourse.redis.setex("estimated_posts_per_day", 1.day.to_i, posts_per_day.to_s)
    posts_per_day
  end

  before_save do
    self.last_editor_id ||= user_id

    if will_save_change_to_raw?
      self.cooked = cook(raw, topic_id: topic_id) if !new_record?
      self.baked_at = Time.zone.now
      self.baked_version = BAKED_VERSION
    end
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
    raw
      .scan(/\[quote=\"([^"]+)"\]/)
      .each do |quote|
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
  def trigger_post_process(
    bypass_bump: false,
    priority: :normal,
    new_post: false,
    skip_pull_hotlinked_images: false
  )
    args = {
      bypass_bump: bypass_bump,
      cooking_options: self.cooking_options,
      new_post: new_post,
      post_id: self.id,
      skip_pull_hotlinked_images: skip_pull_hotlinked_images,
    }

    args[:image_sizes] = image_sizes if self.image_sizes.present?
    args[:invalidate_oneboxes] = true if self.invalidate_oneboxes.present?
    args[:queue] = priority.to_s if priority && priority != :normal

    Jobs.enqueue(:process_post, args)
    DiscourseEvent.trigger(:after_trigger_post_process, self)
  end

  def self.public_posts_count_per_day(
    start_date,
    end_date,
    category_id = nil,
    include_subcategories = false,
    group_ids = nil
  )
    result =
      public_posts.where(
        "posts.created_at >= ? AND posts.created_at <= ?",
        start_date,
        end_date,
      ).where(post_type: Post.types[:regular])

    if category_id
      if include_subcategories
        result = result.where("topics.category_id IN (?)", Category.subcategory_ids(category_id))
      else
        result = result.where("topics.category_id IN (?)", category_id)
      end
    end
    if group_ids
      result =
        result
          .joins("INNER JOIN users ON users.id = posts.user_id")
          .joins("INNER JOIN group_users ON group_users.user_id = users.id")
          .where("group_users.group_id IN (?)", group_ids)
    end

    result.group("date(posts.created_at)").order("date(posts.created_at)").count
  end

  def self.private_messages_count_per_day(start_date, end_date, topic_subtype)
    private_posts
      .with_topic_subtype(topic_subtype)
      .where("posts.created_at >= ? AND posts.created_at <= ?", start_date, end_date)
      .group("date(posts.created_at)")
      .order("date(posts.created_at)")
      .count
  end

  MAX_REPLY_LEVEL = 1000

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
    Scheduler::Defer.later "Index post for search" do
      SearchIndexer.index(self)
    end
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

      # Link any video thumbnails
      if SiteSetting.video_thumbnails_enabled && upload.present? &&
           FileHelper.supported_video.include?(upload.extension&.downcase)
        # Video thumbnails have the filename of the video file sha1 with a .png or .jpg extension.
        # This is because at time of upload in the composer we don't know the topic/post id yet
        # and there is no thumbnail info added to the markdown to tie the thumbnail to the topic/post after
        # creation.
        thumbnail =
          Upload
            .where("original_filename like ?", "#{upload.sha1}.%")
            .order(id: :desc)
            .first if upload.sha1.present?
        if thumbnail.present?
          upload_ids << thumbnail.id
          if self.is_first_post? && !self.topic.image_upload_id
            self.topic.update_column(:image_upload_id, thumbnail.id)
            extra_sizes =
              ThemeModifierHelper.new(
                theme_ids: Theme.user_selectable.pluck(:id),
              ).topic_thumbnail_sizes
            self.topic.generate_thumbnails!(extra_sizes: extra_sizes)
          end
        end
      end
      upload_ids << upload.id if upload.present?
    end

    upload_references =
      upload_ids.map do |upload_id|
        {
          target_id: self.id,
          target_type: self.class.name,
          upload_id: upload_id,
          created_at: Time.zone.now,
          updated_at: Time.zone.now,
        }
      end

    UploadReference.transaction do
      UploadReference.where(target: self).delete_all
      UploadReference.insert_all(upload_references) if upload_references.size > 0

      if SiteSetting.secure_uploads?
        Upload
          .where(id: upload_ids, access_control_post_id: nil)
          .where("id NOT IN (SELECT upload_id FROM custom_emojis)")
          .update_all(access_control_post_id: self.id)
      end
    end
  end

  def update_uploads_secure_status(source:)
    if Discourse.store.external?
      self.uploads.each { |upload| upload.update_secure_status(source: source) }
    end
  end

  def each_upload_url(fragments: nil, include_local_upload: true)
    current_db = RailsMultisite::ConnectionManagement.current_db

    upload_patterns = [
      %r{/uploads/#{current_db}/},
      %r{/original/},
      %r{/optimized/},
      %r{/uploads/short-url/[a-zA-Z0-9]+(\.[a-z0-9]+)?},
    ]

    fragments ||= Nokogiri::HTML5.fragment(self.cooked)

    selectors =
      fragments.css(
        "a/@href",
        "img/@src",
        "source/@src",
        "track/@src",
        "video/@poster",
        "div/@data-video-src",
      )

    links =
      selectors
        .map do |media|
          src = media.value
          next if src.blank?

          if src.end_with?("/images/transparent.png") &&
               (parent = media.parent)["data-orig-src"].present?
            parent["data-orig-src"]
          else
            src
          end
        end
        .compact
        .uniq

    links.each do |src|
      src = src.split("?")[0]

      if src.start_with?("upload://")
        sha1 = Upload.sha1_from_short_url(src)
        yield(src, nil, sha1)
        next
      end

      if src.include?("/uploads/short-url/")
        host =
          begin
            URI(src).host
          rescue URI::Error
          end

        next if host.present? && host != Discourse.current_hostname

        sha1 = Upload.sha1_from_short_path(src)
        yield(src, nil, sha1)
        next
      end

      next if upload_patterns.none? { |pattern| src =~ pattern }
      next if Rails.configuration.multisite && src.exclude?(current_db)

      src = "#{SiteSetting.force_https ? "https" : "http"}:#{src}" if src.start_with?("//")

      if !Discourse.store.has_been_uploaded?(src) && !Upload.secure_uploads_url?(src) &&
           !(include_local_upload && src =~ %r{\A/[^/]}i)
        next
      end

      path =
        begin
          URI(
            UrlHelper.unencode(GlobalSetting.cdn_url ? src.sub(GlobalSetting.cdn_url, "") : src),
          )&.path
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

      query =
        Post
          .have_uploads
          .joins(:topic)
          .joins(
            "LEFT JOIN post_custom_fields ON posts.id = post_custom_fields.post_id AND post_custom_fields.name = '#{Post::MISSING_UPLOADS_IGNORED}'",
          )
          .where("post_custom_fields.id IS NULL")
          .select(:id, :cooked)

      query.find_in_batches do |posts|
        ids = posts.pluck(:id)
        sha1s =
          Upload
            .joins(:upload_references)
            .where(upload_references: { target_type: "Post" })
            .where("upload_references.target_id BETWEEN ? AND ?", ids.min, ids.max)
            .pluck(:sha1)

        posts.each do |post|
          post.each_upload_url do |src, path, sha1|
            next if sha1.present? && sha1s.include?(sha1)

            missing_post_uploads[post.id] ||= []

            if missing_uploads.include?(src)
              missing_post_uploads[post.id] << src
              next
            end

            upload_id = nil
            upload_id = Upload.where(sha1: sha1).pick(:id) if sha1.present?
            upload_id ||= yield(post, src, path, sha1)

            if upload_id.blank?
              missing_uploads << src
              missing_post_uploads[post.id] << src
            end
          end
        end
      end

      missing_post_uploads =
        missing_post_uploads.reject do |post_id, uploads|
          if uploads.present?
            PostCustomField.create!(
              post_id: post_id,
              name: Post::MISSING_UPLOADS,
              value: uploads.to_json,
            )
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

  def image_url
    raw_url = image_upload&.url
    UrlHelper.cook_url(raw_url, secure: image_upload&.secure?, local: true) if raw_url
  end

  def cannot_permanently_delete_reason(user)
    if self.deleted_by_id == user&.id && self.deleted_at >= Post::PERMANENT_DELETE_TIMER.ago
      time_left =
        RateLimiter.time_left(
          Post::PERMANENT_DELETE_TIMER.to_i - Time.zone.now.to_i + self.deleted_at.to_i,
        )
      I18n.t("post.cannot_permanently_delete.wait_or_different_admin", time_left: time_left)
    end
  end

  def mentions
    PrettyText.extract_mentions(Nokogiri::HTML5.fragment(cooked))
  end

  private

  def parse_quote_into_arguments(quote)
    return {} if quote.blank?
    args = HashWithIndifferentAccess.new
    quote.first.scan(/([a-z]+)\:(\d+)/).each { |arg| args[arg[0]] = arg[1].to_i }
    args
  end

  def add_to_quoted_post_numbers(num)
    return if num.blank?
    self.quoted_post_numbers ||= []
    self.quoted_post_numbers << num
  end

  def create_reply_relationship_with(post)
    return if post.nil? || self.deleted_at.present?
    post_reply = post.post_replies.new(reply_post_id: id)
    if post_reply.save
      if Topic.visible_post_types.include?(self.post_type)
        Post.where(id: post.id).update_all ["reply_count = reply_count + 1"]
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
#  locked_by_id            :integer
#  image_upload_id         :bigint
#  outbound_message_id     :string
#
# Indexes
#
#  idx_posts_created_at_topic_id                          (created_at,topic_id) WHERE (deleted_at IS NULL)
#  idx_posts_deleted_posts                                (topic_id,post_number) WHERE (deleted_at IS NOT NULL)
#  idx_posts_user_id_deleted_at                           (user_id) WHERE (deleted_at IS NULL)
#  index_for_rebake_old                                   (id) WHERE (((baked_version IS NULL) OR (baked_version < 2)) AND (deleted_at IS NULL))
#  index_posts_on_id_and_baked_version                    (id DESC,baked_version) WHERE (deleted_at IS NULL)
#  index_posts_on_id_topic_id_where_not_deleted_or_empty  (id,topic_id) WHERE ((deleted_at IS NULL) AND (raw <> ''::text))
#  index_posts_on_image_upload_id                         (image_upload_id)
#  index_posts_on_topic_id_and_created_at                 (topic_id,created_at)
#  index_posts_on_topic_id_and_percent_rank               (topic_id,percent_rank)
#  index_posts_on_topic_id_and_post_number                (topic_id,post_number) UNIQUE
#  index_posts_on_topic_id_and_reply_to_post_number       (topic_id,reply_to_post_number)
#  index_posts_on_topic_id_and_sort_order                 (topic_id,sort_order)
#  index_posts_on_user_id_and_created_at                  (user_id,created_at)
#  index_posts_user_and_likes                             (user_id,like_count DESC,created_at DESC) WHERE (post_number > 1)
#
