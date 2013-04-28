require_dependency 'slug'
require_dependency 'avatar_lookup'
require_dependency 'topic_view'
require_dependency 'rate_limiter'
require_dependency 'text_sentinel'
require_dependency 'text_cleaner'

class Topic < ActiveRecord::Base
  include ActionView::Helpers
  include RateLimiter::OnCreateRecord

  def self.max_sort_order
    2**31 - 1
  end

  def self.featured_users_count
    4
  end

  versioned if: :new_version_required?
  acts_as_paranoid
  after_recover :update_flagged_posts_count
  after_destroy :update_flagged_posts_count

  rate_limit :default_rate_limiter
  rate_limit :limit_topics_per_day
  rate_limit :limit_private_messages_per_day

  validate :title_quality
  validates_presence_of :title
  validate :title, -> { SiteSetting.topic_title_length.include? :length }

  serialize :meta_data, ActiveRecord::Coders::Hstore

  before_validation :sanitize_title
  validate :unique_title

  belongs_to :category
  has_many :posts
  has_many :topic_allowed_users
  has_many :allowed_users, through: :topic_allowed_users, source: :user

  has_one :hot_topic
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

  # When we want to temporarily attach some data to a forum topic (usually before serialization)
  attr_accessor :user_data
  attr_accessor :posters  # TODO: can replace with posters_summary once we remove old list code
  attr_accessor :topic_list

  # The regular order
  scope :topic_list_order, lambda { order('topics.bumped_at desc') }

  # Return private message topics
  scope :private_messages, lambda {
    where(archetype: Archetype::private_message)
  }

  scope :listable_topics, lambda { where('topics.archetype <> ?', [Archetype.private_message]) }

  scope :by_newest, order('topics.created_at desc, topics.id desc')

  # Helps us limit how many favorites can be made in a day
  class FavoriteLimiter < RateLimiter
    def initialize(user)
      super(user, "favorited:#{Date.today.to_s}", SiteSetting.max_favorites_per_day, 1.day.to_i)
    end
  end

  before_create do
    self.bumped_at ||= Time.now
    self.last_post_user_id ||= user_id
  end

  after_create do
    changed_to_category(category)
    TopicUser.change(user_id, id,
                     notification_level: TopicUser.notification_levels[:watching],
                     notifications_reason_id: TopicUser.notification_reasons[:created_topic])
    if archetype == Archetype.private_message
      DraftSequence.next!(user, Draft::NEW_PRIVATE_MESSAGE)
    else
      DraftSequence.next!(user, Draft::NEW_TOPIC)
    end
  end

  # Additional rate limits on topics: per day and private messages per day
  def limit_topics_per_day
    RateLimiter.new(user, "topics-per-day:#{Date.today.to_s}", SiteSetting.max_topics_per_day, 1.day.to_i)
  end

  def limit_private_messages_per_day
    return unless private_message?
    RateLimiter.new(user, "pms-per-day:#{Date.today.to_s}", SiteSetting.max_private_messages_per_day, 1.day.to_i)
  end

  # Validate unique titles if a site setting is set
  def unique_title
    return if SiteSetting.allow_duplicate_topic_titles?

    # Let presence validation catch it if it's blank
    return if title.blank?

    # Private messages can be called whatever they want
    return if private_message?

    finder = Topic.listable_topics.where("lower(title) = ?", title.downcase)
    finder = finder.where("id != ?", self.id) if self.id.present?

    errors.add(:title, I18n.t(:has_already_been_used)) if finder.exists?
  end

  def fancy_title
    return title unless SiteSetting.title_fancy_entities?

    # We don't always have to require this, if fancy is disabled
    # see: http://meta.discourse.org/t/pattern-for-defer-loading-gems-and-profiling-with-perftools-rb/4629
    require 'redcarpet' unless defined? Redcarpet

    Redcarpet::Render::SmartyPants.render(title)
  end

  def title_quality
    # We don't care about quality on private messages
    return if private_message?

    sentinel = TextSentinel.title_sentinel(title)
    if sentinel.valid?
      # clean up the title
      self.title = TextCleaner.clean_title(sentinel.text)
    else
      errors.add(:title, I18n.t(:is_invalid))
    end
  end

  def sanitize_title
    if self.title.present?
      self.title = sanitize(title, tags: [], attributes: [])
      self.title.strip!
    end
  end

  def new_version_required?
    title_changed? || category_id_changed?
  end

  # Returns new topics since a date for display in email digest.
  def self.new_topics(since)
    Topic
      .visible
      .where(closed: false, archived: false)
      .created_since(since)
      .listable_topics
      .topic_list_order
      .includes(:user)
      .limit(5)
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

  def has_meta_data_boolean?(key)
    meta_data_string(key) == 'true'
  end

  def meta_data_string(key)
    return unless meta_data.present?
    meta_data[key.to_s]
  end

  def self.visible
    where(visible: true)
  end

  def self.created_since(time_ago)
    where("created_at > ?", time_ago)
  end

  def self.listable_count_per_day(sinceDaysAgo=30)
    listable_topics.where('created_at > ?', sinceDaysAgo.days.ago).group('date(created_at)').order('date(created_at)').count
  end

  def private_message?
    self.archetype == Archetype.private_message
  end

  def links_grouped
    exec_sql("SELECT ftl.url,
                     ft.title,
                     ftl.link_topic_id,
                     ftl.reflection,
                     ftl.internal,
                     MIN(ftl.user_id) AS user_id,
                     SUM(clicks) AS clicks
              FROM topic_links AS ftl
                LEFT OUTER JOIN topics AS ft ON ftl.link_topic_id = ft.id
              WHERE ftl.topic_id = ?
              GROUP BY ftl.url, ft.title, ftl.link_topic_id, ftl.reflection, ftl.internal
              ORDER BY clicks DESC",
              id).to_a
  end

  # Search for similar topics
  def self.similar_to(title, raw)
    return [] unless title.present?
    return [] unless raw.present?

    # For now, we only match on title. We'll probably add body later on, hence the API hook
    Topic.select(sanitize_sql_array(["topics.*, similarity(topics.title, :title) AS similarity", title: title]))
         .visible
         .where(closed: false, archived: false)
         .listable_topics
         .limit(SiteSetting.max_similar_results)
         .order('similarity desc')
         .all
  end

  def update_status(property, status, user)
    Topic.transaction do

      # Special case: if it's pinned, update that
      if property.to_sym == :pinned
        update_pinned(status)
      else
        # otherwise update the column
        update_column(property, status)
      end

      key = "topic_statuses.#{property}_"
      key << (status ? 'enabled' : 'disabled')

      opts = {}

      # We don't bump moderator posts except for the re-open post.
      opts[:bump] = true if property == 'closed' and (!status)

      add_moderator_post(user, I18n.t(key), opts)
    end
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
                            posts_count = (SELECT count(*) FROM posts WHERE deleted_at IS NULL AND topic_id = :topic_id)
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
                    GROUP BY topic_id) AS x
              WHERE x.topic_id = topics.id")
  end

  def changed_to_category(cat)

    return if cat.blank?
    return if Category.where(topic_id: id).first.present?

    Topic.transaction do
      old_category = category

      if category_id.present? && category_id != cat.id
        Category.update_all 'topic_count = topic_count - 1', ['id = ?', category_id]
      end

      self.category_id = cat.id
      save

      CategoryFeaturedTopic.feature_topics_for(old_category)
      Category.update_all 'topic_count = topic_count + 1', id: cat.id
      CategoryFeaturedTopic.feature_topics_for(cat) unless old_category.try(:id) == cat.try(:id)
    end
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
      if category_id.present?
        CategoryFeaturedTopic.feature_topics_for(category)
        Category.update_all 'topic_count = topic_count - 1', id: category_id
      end
      self.category_id = nil
      save
      return
    end

    cat = Category.where(name: name).first
    return if cat == category
    changed_to_category(cat)
  end

  def featured_user_ids
    [featured_user1_id, featured_user2_id, featured_user3_id, featured_user4_id].uniq.compact
  end

  # Invite a user to the topic by username or email. Returns success/failure
  def invite(invited_by, username_or_email)
    if private_message?
      # If the user exists, add them to the topic.
      user = User.find_by_username_or_email(username_or_email).first
      if user.present?
        if topic_allowed_users.create!(user_id: user.id)
          # Notify the user they've been invited
          user.notifications.create(notification_type: Notification.types[:invited_to_private_message],
                                    topic_id: id,
                                    post_number: 1,
                                    data: { topic_title: title,
                                            display_username: invited_by.username }.to_json)
          return true
        end
      elsif username_or_email =~ /^.+@.+$/
        # If the user doesn't exist, but it looks like an email, invite the user by email.
        return invite_by_email(invited_by, username_or_email)
      end
    else
      # Success is whether the invite was created
      return invite_by_email(invited_by, username_or_email).present?
    end

    false
  end

  # Invite a user by email and return the invite. Return the previously existing invite
  # if already exists. Returns nil if the invite can't be created.
  def invite_by_email(invited_by, email)
    lower_email = Email.downcase(email)
    invite = Invite.with_deleted.where('invited_by_id = ? and email = ?', invited_by.id, lower_email).first

    if invite.blank?
      invite = Invite.create(invited_by: invited_by, email: lower_email)
      unless invite.valid?

        # If the email already exists, grant permission to that user
        if invite.email_already_exists and private_message?
          user = User.where(email: lower_email).first
          topic_allowed_users.create!(user_id: user.id)
        end

        return
      end
    end

    # Recover deleted invites if we invite them again
    invite.recover if invite.deleted_at.present?

    topic_invites.create(invite_id: invite.id)
    Jobs.enqueue(:invite_email, invite_id: invite.id)
    invite
  end

  def move_posts(moved_by, new_title, post_ids)
    topic = nil
    first_post_number = nil
    Topic.transaction do
      topic = Topic.create(user: moved_by, title: new_title, category: category)

      to_move = posts.where(id: post_ids).order(:created_at)
      raise Discourse::InvalidParameters.new(:post_ids) if to_move.blank?

      to_move.each_with_index do |post, i|
        first_post_number ||= post.post_number
        row_count = Post.update_all ["post_number = :post_number, topic_id = :topic_id, sort_order = :post_number", post_number: i+1, topic_id: topic.id], id: post.id, topic_id: id

        # We raise an error if any of the posts can't be moved
        raise Discourse::InvalidParameters.new(:post_ids) if row_count == 0
      end

      # Update denormalized values since we've manually moved stuff
    end

    # Add a moderator post explaining that the post was moved
    if topic.present?
      topic_url = "#{Discourse.base_url}#{topic.relative_url}"
      topic_link = "[#{new_title}](#{topic_url})"

      add_moderator_post(moved_by, I18n.t("move_posts.moderator_post", count: post_ids.size, topic_link: topic_link), post_number: first_post_number)
      Jobs.enqueue(:notify_moved_posts, post_ids: post_ids, moved_by_id: moved_by.id)

      topic.update_statistics
      update_statistics
    end


    topic
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

  # Chooses which topic users to feature
  def feature_topic_users(args={})
    reload

    to_feature = posts

    # Don't include the OP or the last poster
    to_feature = to_feature.where('user_id NOT IN (?, ?)', user_id, last_post_user_id)

    # Exclude a given post if supplied (in the case of deletes)
    to_feature = to_feature.where("id <> ?", args[:except_post_id]) if args[:except_post_id].present?

    # Clear the featured users by default
    Topic.featured_users_count.times do |i|
      send("featured_user#{i+1}_id=", nil)
    end

    # Assign the featured_user{x} columns
    to_feature = to_feature.group(:user_id).order('count_all desc').limit(Topic.featured_users_count)

    to_feature.count.keys.each_with_index do |user_id, i|
      send("featured_user#{i+1}_id=", user_id)
    end

    save
  end

  # Create the summary of the interesting posters in a topic. Cheats to avoid
  # many queries.
  def posters_summary(topic_user = nil, current_user = nil, opts={})
    return @posters_summary if @posters_summary.present?
    descriptions = {}

    # Use an avatar lookup object if we have it, otherwise create one just for this forum topic
    al = opts[:avatar_lookup]
    if al.blank?
      al = AvatarLookup.new([user_id, last_post_user_id, featured_user1_id, featured_user2_id, featured_user3_id])
    end

    # Helps us add a description to a poster
    add_description = lambda do |u, desc|
      if u.present?
        descriptions[u.id] ||= []
        descriptions[u.id] << I18n.t(desc)
      end
    end

    add_description.call(al[user_id], :original_poster)
    add_description.call(al[featured_user1_id], :most_posts)
    add_description.call(al[featured_user2_id], :frequent_poster)
    add_description.call(al[featured_user3_id], :frequent_poster)
    add_description.call(al[featured_user4_id], :frequent_poster)
    add_description.call(al[last_post_user_id], :most_recent_poster)


    @posters_summary = [al[user_id],
                        al[last_post_user_id],
                        al[featured_user1_id],
                        al[featured_user2_id],
                        al[featured_user3_id],
                        al[featured_user4_id]
                        ].compact.uniq[0..4]

    unless @posters_summary[0] == al[last_post_user_id]
      # shuffle last_poster to back
      @posters_summary.reject!{|u| u == al[last_post_user_id]}
      @posters_summary << al[last_post_user_id]
    end
    @posters_summary.map! do |p|
      if p
        result = TopicPoster.new
        result.user = p
        result.description = descriptions[p.id].join(', ')
        result.extras = "latest" if al[last_post_user_id] == p
        result
      else
        nil
      end
    end.compact!

    @posters_summary
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
    TopicUser.where('starred_at > ?', sinceDaysAgo.days.ago).group('date(starred_at)').order('date(starred_at)').count
  end

  # Enable/disable the mute on the topic
  def toggle_mute(user, muted)
    TopicUser.change(user, self.id, notification_level: muted?(user) ? TopicUser.notification_levels[:regular] : TopicUser.notification_levels[:muted] )
  end

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
    slug = ""
    slug = (Slug.for(t).presence || "topic") if t.present?
    write_attribute(:slug, slug)
    write_attribute(:title,t)
  end

  def last_post_url
    "/t/#{slug}/#{id}/#{posts_count}"
  end

  def relative_url(post_number=nil)
    url = "/t/#{slug}/#{id}"
    url << "/#{post_number}" if post_number.present? && post_number.to_i > 1
    url
  end

  def muted?(user)
    return false unless user && user.id
    tu = topic_users.where(user_id: user.id).first
    tu && tu.notification_level == TopicUser.notification_levels[:muted]
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

  # notification stuff
  def notify_watch!(user)
    TopicUser.change(user, id, notification_level: TopicUser.notification_levels[:watching])
  end

  def notify_tracking!(user)
    TopicUser.change(user, id, notification_level: TopicUser.notification_levels[:tracking])
  end

  def notify_regular!(user)
    TopicUser.change(user, id, notification_level: TopicUser.notification_levels[:regular])
  end

  def notify_muted!(user)
    TopicUser.change(user, id, notification_level: TopicUser.notification_levels[:muted])
  end
end
