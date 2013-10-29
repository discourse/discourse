require_dependency 'slug'
require_dependency 'avatar_lookup'
require_dependency 'topic_view'
require_dependency 'rate_limiter'
require_dependency 'text_sentinel'
require_dependency 'text_cleaner'
require_dependency 'trashable'

class Topic < ActiveRecord::Base
  include ActionView::Helpers::SanitizeHelper
  include RateLimiter::OnCreateRecord
  include Trashable
  extend Forwardable

  def_delegator :featured_users, :user_ids, :featured_user_ids
  def_delegator :featured_users, :choose, :feature_topic_users

  def_delegator :notifier, :watch!, :notify_watch!
  def_delegator :notifier, :tracking!, :notify_tracking!
  def_delegator :notifier, :regular!, :notify_regular!
  def_delegator :notifier, :muted!, :notify_muted!
  def_delegator :notifier, :toggle_mute, :toggle_mute

  def self.max_sort_order
    2**31 - 1
  end

  versioned if: :new_version_required?

  def featured_users
    @featured_users ||= TopicFeaturedUsers.new(self)
  end

  def trash!(trashed_by=nil)
    update_category_topic_count_by(-1) if deleted_at.nil?
    super(trashed_by)
    update_flagged_posts_count
  end

  def recover!
    update_category_topic_count_by(1) unless deleted_at.nil?
    super
    update_flagged_posts_count
  end

  rate_limit :default_rate_limiter
  rate_limit :limit_topics_per_day
  rate_limit :limit_private_messages_per_day

  validates :title, :presence => true,
                    :topic_title_length => true,
                    :quality_title => { :unless => :private_message? },
                    :unique_among  => { :unless => Proc.new { |t| (SiteSetting.allow_duplicate_topic_titles? || t.private_message?) },
                                        :message => :has_already_been_used,
                                        :allow_blank => true,
                                        :case_sensitive => false,
                                        :collection => Proc.new{ Topic.listable_topics } }

  validates :category_id, :presence => true ,:exclusion => {:in => [SiteSetting.uncategorized_category_id]},
                                     :if => Proc.new { |t|
                                           (t.new_record? || t.category_id_changed?) &&
                                           !SiteSetting.allow_uncategorized_topics &&
                                           (t.archetype.nil? || t.archetype == Archetype.default)
                                       }


  before_validation do
    self.sanitize_title
    self.title = TextCleaner.clean_title(TextSentinel.title_sentinel(title).text) if errors[:title].empty?
  end

  unless rails4?
    serialize :meta_data, ActiveRecord::Coders::Hstore
  end

  belongs_to :category
  has_many :posts
  has_many :topic_allowed_users
  has_many :topic_allowed_groups

  has_many :allowed_group_users, through: :allowed_groups, source: :users
  has_many :allowed_groups, through: :topic_allowed_groups, source: :group
  has_many :allowed_users, through: :topic_allowed_users, source: :user

  has_one :hot_topic
  belongs_to :user
  belongs_to :last_poster, class_name: 'User', foreign_key: :last_post_user_id
  belongs_to :featured_user1, class_name: 'User', foreign_key: :featured_user1_id
  belongs_to :featured_user2, class_name: 'User', foreign_key: :featured_user2_id
  belongs_to :featured_user3, class_name: 'User', foreign_key: :featured_user3_id
  belongs_to :featured_user4, class_name: 'User', foreign_key: :featured_user4_id
  belongs_to :auto_close_user, class_name: 'User', foreign_key: :auto_close_user_id

  has_many :topic_users
  has_many :topic_links
  has_many :topic_invites
  has_many :invites, through: :topic_invites, source: :invite

  # When we want to temporarily attach some data to a forum topic (usually before serialization)
  attr_accessor :user_data
  attr_accessor :posters  # TODO: can replace with posters_summary once we remove old list code
  attr_accessor :topic_list
  attr_accessor :include_last_poster

  # The regular order
  scope :topic_list_order, lambda { order('topics.bumped_at desc') }

  # Return private message topics
  scope :private_messages, lambda {
    where(archetype: Archetype.private_message)
  }

  scope :listable_topics, lambda { where('topics.archetype <> ?', [Archetype.private_message]) }

  scope :by_newest, -> { order('topics.created_at desc, topics.id desc') }

  scope :visible, -> { where(visible: true) }

  scope :created_since, lambda { |time_ago| where('created_at > ?', time_ago) }

  scope :secured, lambda {|guardian=nil|
    ids = guardian.secure_category_ids if guardian

    # Query conditions
    condition =
      if ids.present?
        ["NOT c.read_restricted or c.id in (:cats)", cats: ids]
      else
        ["NOT c.read_restricted"]
      end

    where("category_id IS NULL OR category_id IN (
           SELECT c.id FROM categories c
           WHERE #{condition[0]})", condition[1])
  }

  # Helps us limit how many favorites can be made in a day
  class FavoriteLimiter < RateLimiter
    def initialize(user)
      super(user, "favorited:#{Date.today.to_s}", SiteSetting.max_favorites_per_day, 1.day.to_i)
    end
  end

  before_create do
    self.bumped_at ||= Time.now
    self.last_post_user_id ||= user_id
    if !@ignore_category_auto_close and self.category and self.category.auto_close_days and self.auto_close_at.nil?
      set_auto_close(self.category.auto_close_days)
    end
  end

  attr_accessor :skip_callbacks

  after_create do
    return if skip_callbacks

    changed_to_category(category)
    if archetype == Archetype.private_message
      DraftSequence.next!(user, Draft::NEW_PRIVATE_MESSAGE)
    else
      DraftSequence.next!(user, Draft::NEW_TOPIC)
    end
  end

  before_save do
    return if skip_callbacks

    if (auto_close_at_changed? and !auto_close_at_was.nil?) or (auto_close_user_id_changed? and auto_close_at)
      self.auto_close_started_at ||= Time.zone.now if auto_close_at
      Jobs.cancel_scheduled_job(:close_topic, {topic_id: id})
      true
    end
    if category_id.nil? && (archetype.nil? || archetype == Archetype.default)
      self.category_id = SiteSetting.uncategorized_category_id
    end
  end

  after_save do
    return if skip_callbacks

    if auto_close_at and (auto_close_at_changed? or auto_close_user_id_changed?)
      Jobs.enqueue_at(auto_close_at, :close_topic, {topic_id: id, user_id: auto_close_user_id || user_id})
    end
  end

  def self.count_exceeds_minimum?
    count > SiteSetting.minimum_topics_similar
  end

  def best_post
    posts.order('score desc').limit(1).first
  end

  # all users (in groups or directly targetted) that are going to get the pm
  def all_allowed_users
    # TODO we should probably change this from 3 queries to 1
    User.where('id in (?)', allowed_users.select('users.id').to_a + allowed_group_users.select('users.id').to_a)
  end

  # Additional rate limits on topics: per day and private messages per day
  def limit_topics_per_day
    apply_per_day_rate_limit_for("topics", :max_topics_per_day)
    limit_first_day_topics_per_day if user.added_a_day_ago?
  end

  def limit_private_messages_per_day
    return unless private_message?
    apply_per_day_rate_limit_for("pms", :max_private_messages_per_day)
  end

  def fancy_title
    return title unless SiteSetting.title_fancy_entities?

    # We don't always have to require this, if fancy is disabled
    # see: http://meta.discourse.org/t/pattern-for-defer-loading-gems-and-profiling-with-perftools-rb/4629
    require 'redcarpet' unless defined? Redcarpet

    Redcarpet::Render::SmartyPants.render(title)
  end

  def sanitize_title
    self.title = sanitize(title.to_s, tags: [], attributes: []).strip.presence
  end

  def new_version_required?
    title_changed? || category_id_changed?
  end

  # Returns hot topics since a date for display in email digest.
  def self.for_digest(user, since)
    Topic
      .visible
      .secured(Guardian.new(user))
      .where(closed: false, archived: false)
      .created_since(since)
      .listable_topics
      .order(:percent_rank)
      .limit(100)
  end

  def update_meta_data(data)
    self.meta_data = (self.meta_data || {}).merge(data.stringify_keys)
    save
  end

  def reload(options=nil)
    @post_numbers = nil
    super(options)
  end

  def post_numbers
    @post_numbers ||= posts.order(:post_number).pluck(:post_number)
  end

  def age_in_days
    ((Time.zone.now - created_at) / 1.day).round
  end

  def has_meta_data_boolean?(key)
    meta_data_string(key) == 'true'
  end

  def meta_data_string(key)
    return unless meta_data.present?
    meta_data[key.to_s]
  end

  def self.listable_count_per_day(sinceDaysAgo=30)
    listable_topics.where('created_at > ?', sinceDaysAgo.days.ago).group('date(created_at)').order('date(created_at)').count
  end

  def private_message?
    archetype == Archetype.private_message
  end

  # Search for similar topics
  def self.similar_to(title, raw, user=nil)
    return [] unless title.present?
    return [] unless raw.present?

    # For now, we only match on title. We'll probably add body later on, hence the API hook
    Topic.select(sanitize_sql_array(["topics.*, similarity(topics.title, :title) AS similarity", title: title]))
         .visible
         .where(closed: false, archived: false)
         .secured(Guardian.new(user))
         .listable_topics
         .limit(SiteSetting.max_similar_results)
         .order('similarity desc')
  end

  def update_status(status, enabled, user)
    TopicStatusUpdate.new(self, user).update! status, enabled
  end

  # Atomically creates the next post number
  def self.next_post_number(topic_id, reply = false)
    highest = exec_sql("select coalesce(max(post_number),0) as max from posts where topic_id = ?", topic_id).first['max'].to_i

    reply_sql = reply ? ", reply_count = reply_count + 1" : ""
    result = exec_sql("UPDATE topics SET highest_post_number = ? + 1#{reply_sql}
                       WHERE id = ? RETURNING highest_post_number", highest, topic_id)
    result.first['highest_post_number'].to_i
  end

  # If a post is deleted we have to update our highest post counters
  def self.reset_highest(topic_id)
    result = exec_sql "UPDATE topics
                        SET highest_post_number = (SELECT COALESCE(MAX(post_number), 0) FROM posts WHERE topic_id = :topic_id AND deleted_at IS NULL),
                            posts_count = (SELECT count(*) FROM posts WHERE deleted_at IS NULL AND topic_id = :topic_id),
                            last_posted_at = (SELECT MAX(created_at) FROM POSTS WHERE topic_id = :topic_id AND deleted_at IS NULL)
                        WHERE id = :topic_id
                        RETURNING highest_post_number", topic_id: topic_id
    highest_post_number = result.first['highest_post_number'].to_i

    # Update the forum topic user records
    exec_sql "UPDATE topic_users
              SET last_read_post_number = CASE
                                          WHEN last_read_post_number > :highest THEN :highest
                                          ELSE last_read_post_number
                                          END,
                  seen_post_count = CASE
                                    WHEN seen_post_count > :highest THEN :highest
                                    ELSE seen_post_count
                                    END
              WHERE topic_id = :topic_id",
              highest: highest_post_number,
              topic_id: topic_id
  end

  # This calculates the geometric mean of the posts and stores it with the topic
  def self.calculate_avg_time
    exec_sql("UPDATE topics
              SET avg_time = x.gmean
              FROM (SELECT topic_id,
                           round(exp(avg(ln(avg_time)))) AS gmean
                    FROM posts
                    WHERE avg_time > 0 AND avg_time IS NOT NULL
                    GROUP BY topic_id) AS x
              WHERE x.topic_id = topics.id AND (topics.avg_time <> x.gmean OR topics.avg_time IS NULL)")
  end

  def changed_to_category(cat)
    return true if cat.blank? || Category.where(topic_id: id).first.present?

    Topic.transaction do
      old_category = category

      if category_id.present? && category_id != cat.id
        Category.where(['id = ?', category_id]).update_all 'topic_count = topic_count - 1'
      end

      success = true
      if self.category_id != cat.id
        self.category_id = cat.id
        success = save
      end

      if success
        CategoryFeaturedTopic.feature_topics_for(old_category)
        Category.where(id: cat.id).update_all 'topic_count = topic_count + 1'
        CategoryFeaturedTopic.feature_topics_for(cat) unless old_category.try(:id) == cat.try(:id)
      else
        return false
      end
    end
    true
  end

  def add_moderator_post(user, text, opts={})
    new_post = nil
    Topic.transaction do
      creator = PostCreator.new(user,
                                raw: text,
                                post_type: Post.types[:moderator_action],
                                no_bump: opts[:bump].blank?,
                                topic_id: self.id)
      new_post = creator.create
      increment!(:moderator_posts_count)
      new_post
    end

    if new_post.present?
      # If we are moving posts, we want to insert the moderator post where the previous posts were
      # in the stream, not at the end.
      new_post.update_attributes(post_number: opts[:post_number], sort_order: opts[:post_number]) if opts[:post_number].present?

      # Grab any links that are present
      TopicLink.extract_from(new_post)
    end

    new_post
  end

  # Changes the category to a new name
  def change_category(name)
    # If the category name is blank, reset the attribute
    if name.blank?
      cat = Category.where(id: SiteSetting.uncategorized_category_id).first
    else
      cat = Category.where(name: name).first
    end

    return true if cat == category
    return false unless cat
    changed_to_category(cat)
  end


  def remove_allowed_user(username)
    user = User.where(username: username).first
    if user
      topic_user = topic_allowed_users.where(user_id: user.id).first
      if topic_user
        topic_user.destroy
      else
        false
      end
    end
  end

  # Invite a user to the topic by username or email. Returns success/failure
  def invite(invited_by, username_or_email)
    if private_message?
      # If the user exists, add them to the topic.
      user = User.find_by_username_or_email(username_or_email)
      if user && topic_allowed_users.create!(user_id: user.id)

        # Notify the user they've been invited
        user.notifications.create(notification_type: Notification.types[:invited_to_private_message],
                                  topic_id: id,
                                  post_number: 1,
                                  data: { topic_title: title,
                                          display_username: invited_by.username }.to_json)
        return true
      end
    end

    if username_or_email =~ /^.+@.+$/
      # NOTE callers expect an invite object if an invite was sent via email
      invite_by_email(invited_by, username_or_email)
    else
      false
    end
  end

  # Invite a user by email and return the invite. Return the previously existing invite
  # if already exists. Returns nil if the invite can't be created.
  def invite_by_email(invited_by, email)
    lower_email = Email.downcase(email)
    invite = Invite.with_deleted.where('invited_by_id = ? and email = ?', invited_by.id, lower_email).first

    if invite.blank?
      invite = Invite.create(invited_by: invited_by, email: lower_email)
      unless invite.valid?

        grant_permission_to_user(lower_email) if email_already_exists_for?(invite)

        return
      end
    end

    # Recover deleted invites if we invite them again
    invite.recover if invite.deleted_at.present?

    topic_invites.create(invite_id: invite.id)
    Jobs.enqueue(:invite_email, invite_id: invite.id)
    invite
  end

  def email_already_exists_for?(invite)
    invite.email_already_exists and private_message?
  end

  def grant_permission_to_user(lower_email)
    user = User.where(email: lower_email).first
    topic_allowed_users.create!(user_id: user.id)
  end

  def max_post_number
    posts.maximum(:post_number).to_i
  end

  def move_posts(moved_by, post_ids, opts)
    post_mover = PostMover.new(self, moved_by, post_ids)

    if opts[:destination_topic_id]
      post_mover.to_topic opts[:destination_topic_id]
    elsif opts[:title]
      post_mover.to_new_topic(opts[:title], opts[:category_id])
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
    PostActionType.types.keys.each do |type|
      count_field = "#{type}_count"
      update_column(count_field, Post.where(topic_id: id).sum(count_field))
    end
  end


  def posters_summary(options = {})
    @posters_summary ||= TopicPostersSummary.new(self, options).summary
  end

  # Enable/disable the star on the topic
  def toggle_star(user, starred)
    Topic.transaction do
      TopicUser.change(user, id, {starred: starred}.merge( starred ? {starred_at: DateTime.now, unstarred_at: nil} : {unstarred_at: DateTime.now}))

      # Update the star count
      exec_sql "UPDATE topics
                SET star_count = (SELECT COUNT(*)
                                  FROM topic_users AS ftu
                                  WHERE ftu.topic_id = topics.id
                                    AND ftu.starred = true)
                WHERE id = ?", id

      if starred
        FavoriteLimiter.new(user).performed!
      else
        FavoriteLimiter.new(user).rollback!
      end
    end
  end

  def self.starred_counts_per_day(sinceDaysAgo=30)
    TopicUser.starred_since(sinceDaysAgo).by_date_starred.count
  end

  # Even if the slug column in the database is null, topic.slug will return something:
  def slug
    unless slug = read_attribute(:slug)
      return '' unless title.present?
      slug = Slug.for(title).presence || "topic"
      if new_record?
        write_attribute(:slug, slug)
      else
        update_column(:slug, slug)
      end
    end

    slug
  end

  def title=(t)
    slug = (Slug.for(t.to_s).presence || "topic")
    write_attribute(:slug, slug)
    write_attribute(:title,t)
  end

  # NOTE: These are probably better off somewhere else.
  #       Having a model know about URLs seems a bit strange.
  def last_post_url
    "/t/#{slug}/#{id}/#{posts_count}"
  end

  def self.url(id, slug, post_number=nil)
    url = "#{Discourse.base_url}/t/#{slug}/#{id}"
    url << "/#{post_number}" if post_number.to_i > 1
    url
  end

  def url(post_number = nil)
    self.class.url id, slug, post_number
  end

  def relative_url(post_number=nil)
    url = "/t/#{slug}/#{id}"
    url << "/#{post_number}" if post_number.to_i > 1
    url
  end

  def clear_pin_for(user)
    return unless user.present?
    TopicUser.change(user.id, id, cleared_pinned_at: Time.now)
  end

  def update_pinned(status)
    update_column(:pinned_at, status ? Time.now : nil)
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

  def auto_close_days=(num_days)
    @ignore_category_auto_close = true
    set_auto_close(num_days)
  end

  def set_auto_close(num_days, by_user=nil)
    num_days = num_days.to_i
    self.auto_close_at = (num_days > 0 ? num_days.days.from_now : nil)
    if num_days > 0
      self.auto_close_started_at ||= Time.zone.now
      if by_user and by_user.staff?
        self.auto_close_user = by_user
      else
        self.auto_close_user ||= (self.user.staff? ? self.user : Discourse.system_user)
      end
    else
      self.auto_close_started_at = nil
    end
    self
  end

  def read_restricted_category?
    category && category.read_restricted
  end

  private

  def update_category_topic_count_by(num)
    if category_id.present?
      Category.where(['id = ?', category_id]).update_all("topic_count = topic_count " + (num > 0 ? '+' : '') + "#{num}")
    end
  end

  def limit_first_day_topics_per_day
    apply_per_day_rate_limit_for("first-day-topics", :max_topics_in_first_day)
  end

  def apply_per_day_rate_limit_for(key, method_name)
    RateLimiter.new(user, "#{key}-per-day:#{Date.today.to_s}", SiteSetting.send(method_name), 1.day.to_i)
  end

end

# == Schema Information
#
# Table name: topics
#
#  id                      :integer          not null, primary key
#  title                   :string(255)      not null
#  last_posted_at          :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  views                   :integer          default(0), not null
#  posts_count             :integer          default(0), not null
#  user_id                 :integer
#  last_post_user_id       :integer          not null
#  reply_count             :integer          default(0), not null
#  featured_user1_id       :integer
#  featured_user2_id       :integer
#  featured_user3_id       :integer
#  avg_time                :integer
#  deleted_at              :datetime
#  highest_post_number     :integer          default(0), not null
#  image_url               :string(255)
#  off_topic_count         :integer          default(0), not null
#  like_count              :integer          default(0), not null
#  incoming_link_count     :integer          default(0), not null
#  bookmark_count          :integer          default(0), not null
#  star_count              :integer          default(0), not null
#  category_id             :integer
#  visible                 :boolean          default(TRUE), not null
#  moderator_posts_count   :integer          default(0), not null
#  closed                  :boolean          default(FALSE), not null
#  archived                :boolean          default(FALSE), not null
#  bumped_at               :datetime         not null
#  has_best_of             :boolean          default(FALSE), not null
#  meta_data               :hstore
#  vote_count              :integer          default(0), not null
#  archetype               :string(255)      default("regular"), not null
#  featured_user4_id       :integer
#  notify_moderators_count :integer          default(0), not null
#  spam_count              :integer          default(0), not null
#  illegal_count           :integer          default(0), not null
#  inappropriate_count     :integer          default(0), not null
#  pinned_at               :datetime
#  score                   :float
#  percent_rank            :float            default(1.0), not null
#  notify_user_count       :integer          default(0), not null
#  subtype                 :string(255)
#  slug                    :string(255)
#  auto_close_at           :datetime
#  auto_close_user_id      :integer
#  auto_close_started_at   :datetime
#  deleted_by_id           :integer
#
# Indexes
#
#  idx_topics_user_id_deleted_at                                (user_id)
#  index_forum_threads_on_bumped_at                             (bumped_at)
#  index_topics_on_deleted_at_and_visible_and_archetype_and_id  (deleted_at,visible,archetype,id)
#  index_topics_on_id_and_deleted_at                            (id,deleted_at)
#

