require_dependency 'jobs'
require_dependency 'pretty_text'
require_dependency 'rate_limiter'

require 'archetype'
require 'hpricot'
require 'digest/sha1'

class Post < ActiveRecord::Base
  include RateLimiter::OnCreateRecord

  module HiddenReason
    FLAG_THRESHOLD_REACHED = 1
    FLAG_THRESHOLD_REACHED_AGAIN = 2
  end

  # A custom rate limiter for edits
  class EditRateLimiter < RateLimiter
    def initialize(user)
      super(user, "edit-post:#{Date.today.to_s}", SiteSetting.max_edits_per_day, 1.day.to_i)
    end
  end

  versioned

  rate_limit

  acts_as_paranoid
  after_recover :update_flagged_posts_count
  after_destroy :update_flagged_posts_count

  belongs_to :user
  belongs_to :topic, counter_cache: :posts_count

  has_many :post_replies
  has_many :replies, through: :post_replies
  has_many :post_actions

  validates_presence_of :raw, :user_id, :topic_id
  validates :raw, length: {in: SiteSetting.min_post_length..SiteSetting.max_post_length}
  validate :raw_quality
  validate :max_mention_validator
  validate :max_images_validator
  validate :max_links_validator
  validate :unique_post_validator

  # We can pass a hash of image sizes when saving to prevent crawling those images
  attr_accessor :image_sizes, :quoted_post_numbers, :no_bump, :invalidate_oneboxes

  SHORT_POST_CHARS = 1200

  # Post Types
  REGULAR = 1
  MODERATOR_ACTION = 2

  before_save :extract_quoted_post_numbers
  after_commit :feature_topic_users, on: :create
  after_commit :trigger_post_process, on: :create
  after_commit :email_private_message, on: :create

  # Related to unique post tracking
  after_commit :store_unique_post_key, on: :create

  after_create do
    TopicUser.auto_track(self.user_id, self.topic_id, TopicUser::NotificationReasons::CREATED_POST)
  end

  before_validation do
    self.raw.strip! if self.raw.present?
  end

  def raw_quality

    sentinel = TextSentinel.new(self.raw, min_entropy: SiteSetting.body_min_entropy)
    if sentinel.valid?
      # It's possible the sentinel has cleaned up the title a bit
      self.raw = sentinel.text
    else
      errors.add(:raw, I18n.t(:is_invalid)) unless sentinel.valid?
    end
  end


  # Stop us from posting the same thing too quickly
  def unique_post_validator
    return if SiteSetting.unique_posts_mins == 0
    return if user.admin? or user.has_trust_level?(:moderator)

    # If the post is empty, default to the validates_presence_of
    return if raw.blank?

    if $redis.exists(unique_post_key)
      errors.add(:raw, I18n.t(:just_posted_that))
    end
  end

  # On successful post, store a hash key to prevent the same post from happening again
  def store_unique_post_key
    return if SiteSetting.unique_posts_mins == 0
    $redis.setex(unique_post_key, SiteSetting.unique_posts_mins.minutes.to_i, "1")
  end

  # The key we use in reddit to ensure unique posts
  def unique_post_key
    "post-#{user_id}:#{raw_hash}"
  end

  def raw_hash
    return nil if raw.blank?
    Digest::SHA1.hexdigest(raw.gsub(/\s+/, "").downcase)
  end

  def cooked_document
    self.cooked ||= cook(self.raw, topic_id: topic_id)
    @cooked_document ||= Nokogiri::HTML.fragment(self.cooked)
  end

  def image_count
    return 0 unless self.raw.present?
    cooked_document.search("img.emoji").remove
    cooked_document.search("img").count
  end

  def link_count
    return 0 unless self.raw.present?
    cooked_document.search("a[href]").count
  end

  def max_mention_validator
    errors.add(:raw, I18n.t(:too_many_mentions)) if raw_mentions.size > SiteSetting.max_mentions_per_post
  end

  def max_images_validator
    return if user.present? and user.has_trust_level?(:basic)
    errors.add(:raw, I18n.t(:too_many_images)) if image_count > 0
  end

  def max_links_validator
    return if user.present? and user.has_trust_level?(:basic)
    errors.add(:raw, I18n.t(:too_many_links)) if link_count > 1
  end


  def raw_mentions
    return [] if raw.blank?

    # We don't count mentions in quotes
    return @raw_mentions if @raw_mentions.present?
    raw_stripped = raw.gsub(/\[quote=(.*)\]([^\[]*?)\[\/quote\]/im, '')

    # Strip pre and code tags
    doc = Nokogiri::HTML.fragment(raw_stripped)
    doc.search("pre").remove
    doc.search("code").remove

    results = doc.to_html.scan(PrettyText.mention_matcher)
    if results.present?
      @raw_mentions = results.uniq.map {|un| un.first.downcase.gsub!(/^@/, '')}
    else
      @raw_mentions = []
    end

  end

  def archetype
    topic.archetype
  end

  def self.regular_order
    order(:sort_order, :post_number)
  end

  def self.reverse_order
    order('sort_order desc, post_number desc')
  end

  def self.best_of
    where("(post_number = 1) or (score >= ?)", SiteSetting.best_of_score_threshold)
  end

  def update_flagged_posts_count
    PostAction.update_flagged_posts_count
  end

  def filter_quotes(parent_post=nil)
    return cooked if parent_post.blank?

    # We only filter quotes when there is exactly 1
    return cooked unless (quote_count == 1)

    parent_raw = parent_post.raw.sub(/\[quote.+\/quote\]/m, '').strip

    if raw[parent_raw] or (parent_raw.size < SHORT_POST_CHARS)
      return cooked.sub(/\<aside.+\<\/aside\>/m, '')
    end

    cooked
  end

  def username
    user.username
  end

  def external_id
    "#{topic_id}/#{post_number}"
  end

  def quoteless?
    (quote_count == 0) and (reply_to_post_number.present?)
  end

  # Get the post that we reply to.
  def reply_to_user
    return nil unless reply_to_post_number.present?
    User.where('id = (select user_id from posts where topic_id = ? and post_number = ?)', topic_id, reply_to_post_number).first
  end

  def reply_notification_target
    return nil unless reply_to_post_number.present?
    reply_post = Post.where("topic_id = :topic_id AND post_number = :post_number AND user_id <> :user_id",
                            topic_id: topic_id,
                            post_number: reply_to_post_number,
                            user_id: user_id).first
    return reply_post.try(:user)
  end

  def self.excerpt(cooked, maxlength=nil)
    maxlength ||= SiteSetting.post_excerpt_maxlength
    PrettyText.excerpt(cooked, maxlength)
  end

  # Strip out most of the markup
  def excerpt(maxlength=nil)
    Post.excerpt(cooked, maxlength)
  end

  # What we use to cook posts
  def cook(*args)
    cooked = PrettyText.cook(*args)

    # If we have any of the oneboxes in the cache, throw them in right away, don't
    # wait for the post processor.
    dirty = false
    doc = Oneboxer.each_onebox_link(cooked) do |url, elem|
      cached = Oneboxer.render_from_cache(url)
      if cached.present?
        elem.swap(cached.cooked)
        dirty = true
      end
    end

    cooked = doc.to_html if dirty
    cooked
  end

  # A list of versions including the initial version
  def all_versions
    result = []
    result << {number: 1, display_username: user.name, created_at: created_at}
    versions.order(:number).includes(:user).each do |v|
      result << {number: v.number, display_username: v.user.name, created_at: v.created_at}
    end
    result
  end

  def is_flagged?
    post_actions.where('post_action_type_id in (?) and deleted_at is null', PostActionType.FlagTypes).count != 0
  end

  def unhide!
    self.hidden = false
    self.hidden_reason_id = nil
    self.topic.update_attributes(visible: true)
    self.save
  end

  # Update the body of a post. Will create a new version when appropriate
  def revise(updated_by, new_raw, opts={})

    # Only update if it changes
    return false if self.raw == new_raw

    updater = lambda do |new_version=false|

      # Raw is about to change, enable validations
      @cooked_document = nil
      self.cooked = nil

      self.raw = new_raw
      self.updated_by = updated_by
      self.last_editor_id = updated_by.id

      if self.hidden && self.hidden_reason_id == HiddenReason::FLAG_THRESHOLD_REACHED
        self.hidden = false
        self.hidden_reason_id = nil
        self.topic.update_attributes(visible: true)

        PostAction.clear_flags!(self, -1)
      end

      self.save
    end

    # We can optionally specify when this version was revised. Defaults to now.
    revised_at = opts[:revised_at] || Time.now
    new_version = false

    # We always create a new version if the poster has changed
    new_version = true if (self.last_editor_id != updated_by.id)

    # We always create a new version if it's been greater than the ninja edit window
    new_version = true if (revised_at - last_version_at) > SiteSetting.ninja_edit_window.to_i

    # Create the new version (or don't)
    if new_version

      self.cached_version = version + 1

      Post.transaction do
        self.last_version_at = revised_at
        updater.call(true)
        EditRateLimiter.new(updated_by).performed! unless opts[:bypass_rate_limiter]

        # If a new version is created of the last post, bump it.
        unless Post.where('post_number > ? and topic_id = ?', self.post_number, self.topic_id).exists?
          topic.update_column(:bumped_at, Time.now) unless opts[:bypass_bump]
        end
      end

    else
      skip_version(&updater)
    end

    # Invalidate any oneboxes
    self.invalidate_oneboxes = true
    trigger_post_process

    true
  end


  def url
    "/t/#{Slug.for(topic.title)}/#{topic.id}/#{post_number}"
  end

  # Various callbacks
  before_create do
    self.post_number ||= Topic.next_post_number(topic_id, reply_to_post_number.present?)
    self.cooked ||= cook(raw, topic_id: topic_id)
    self.sort_order = post_number
    DiscourseEvent.trigger(:before_create_post, self)
    self.last_version_at ||= Time.now
  end

  # TODO: Move some of this into an asynchronous job?
  after_create do

    # Update attributes on the topic - featured users and last posted.
    attrs = {last_posted_at: self.created_at, last_post_user_id: self.user_id}
    attrs[:bumped_at] = self.created_at unless no_bump
    topic.update_attributes(attrs)

    # Update the user's last posted at date
    user.update_column(:last_posted_at, self.created_at)

    # Update topic user data
    TopicUser.change(user,
                           topic.id,
                           posted: true,
                           last_read_post_number: self.post_number,
                           seen_post_count: self.post_number)
  end

  def email_private_message
    # send a mail to notify users in case of a private message
    if topic.private_message?
      topic.allowed_users.where(["users.email_private_messages = true and users.id != ?", self.user_id]).each do |u|
        Jobs.enqueue_in(SiteSetting.email_time_window_mins.minutes, :user_email, type: :private_message, user_id: u.id, post_id: self.id)
      end
    end
  end

  def feature_topic_users
    Jobs.enqueue(:feature_topic_users, topic_id: self.topic_id)
  end

  # This calculates the geometric mean of the post timings and stores it along with
  # each post.
  def self.calculate_avg_time
    exec_sql("UPDATE posts
              SET avg_time = (x.gmean / 1000)
              FROM (SELECT post_timings.topic_id,
                           post_timings.post_number,
                           round(exp(avg(ln(msecs)))) AS gmean
                    FROM post_timings
                    INNER JOIN posts AS p2
                      ON p2.post_number = post_timings.post_number
                        AND p2.topic_id = post_timings.topic_id
                        AND p2.user_id <> post_timings.user_id
                    GROUP BY post_timings.topic_id, post_timings.post_number) AS x
              WHERE x.topic_id = posts.topic_id
                AND x.post_number = posts.post_number")
  end

  before_save do
    self.last_editor_id ||= self.user_id
    self.cooked = cook(raw, topic_id: topic_id) unless new_record?
  end

  before_destroy do

    # Update the last post id to the previous post if it exists
    last_post = Post.where("topic_id = ? and id <> ?", self.topic_id, self.id).order('created_at desc').limit(1).first
    if last_post.present?
      topic.update_attributes(last_posted_at: last_post.created_at,
                              last_post_user_id: last_post.user_id,
                              highest_post_number: last_post.post_number)

      # If the poster doesn't have any other posts in the topic, clear their posted flag
      unless Post.exists?(["topic_id = ? and user_id = ? and id <> ?", self.topic_id, self.user_id, self.id])
        TopicUser.update_all 'posted = false', ['topic_id = ? and user_id = ?', self.topic_id, self.user_id]
      end
    end

    # Feature users in the topic
    Jobs.enqueue(:feature_topic_users, topic_id: topic_id, except_post_id: self.id)

  end

  after_destroy do

    # Remove any reply records that point to deleted posts
    post_ids = PostReply.select(:post_id).where(reply_id: self.id).map(&:post_id)
    PostReply.delete_all ["reply_id = ?", self.id]

    if post_ids.present?
      Post.where(id: post_ids).each {|p| p.update_column :reply_count, p.replies.count}
    end

    # Remove any notifications that point to this deleted post
    Notification.delete_all ["topic_id = ? and post_number = ?", self.topic_id, self.post_number]
  end

  after_save do

    DraftSequence.next! self.last_editor_id, self.topic.draft_key if self.topic # could be deleted

    quoted_post_numbers << reply_to_post_number if reply_to_post_number.present?

    # Create a reply relationship between quoted posts and this new post
    if self.quoted_post_numbers.present?
      self.quoted_post_numbers.map! {|pid| pid.to_i}.uniq!
      self.quoted_post_numbers.each do |p|
        post = Post.where(topic_id: topic_id, post_number: p).first
        if post.present?
          post_reply = post.post_replies.new(reply_id: self.id)
          if post_reply.save
            Post.update_all ['reply_count = reply_count + 1, reply_below_post_number = COALESCE(reply_below_post_number, ?)', self.post_number],
                            ["id = ?", post.id]
          end
        end
      end
    end
  end

  def extract_quoted_post_numbers
    self.quoted_post_numbers = []

    # Create relationships for the quotes
    raw.scan(/\[quote=\"([^"]+)"\]/).each do |m|
      if m.present?
        args = {}
        m.first.scan(/([a-z]+)\:(\d+)/).each do |arg|
          args[arg[0].to_sym] = arg[1].to_i
        end

        if args[:topic].present?
          # If the topic attribute is present, ensure it's the same topic
          self.quoted_post_numbers << args[:post] if self.topic_id == args[:topic]
        else
          self.quoted_post_numbers << args[:post]
        end

      end
    end

    self.quoted_post_numbers.uniq!
    self.quote_count = self.quoted_post_numbers.size
  end

  # Process this post after comitting it
  def trigger_post_process
    args = {post_id: self.id}
    args[:image_sizes] = self.image_sizes if self.image_sizes.present?
    args[:invalidate_oneboxes] = true if self.invalidate_oneboxes.present?
    Jobs.enqueue(:process_post, args)
  end

end
