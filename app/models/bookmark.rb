# frozen_string_literal: true

class Bookmark < ActiveRecord::Base
  # these columns were here for a very short amount of time,
  # hence the very short ignore time
  self.ignored_columns = [
    "topic_id", # TODO 2022-04-01: remove
    "reminder_type" # TODO 2021-04-01: remove
  ]

  cattr_accessor :registered_bookmarkables
  self.registered_bookmarkables = []

  def self.register_bookmarkable(
    model:, serializer:, list_query:, search_query:, preload_associations: []
  )
    Bookmark.registered_bookmarkables << Bookmarkable.new(
      model: model,
      serializer: serializer,
      list_query: list_query,
      search_query: search_query,
      preload_associations: preload_associations
    )
  end

  ##
  # This is called when the app loads, similar to AdminDashboardData.reset_problem_checks,
  # so the default Post and Topic bookmarkables are registered on
  # boot.
  #
  # This method also can be used in testing to reset bookmarkables between
  # tests. It will also fire multiple times in development mode because
  # classes are not cached.
  def self.reset_bookmarkables
    self.registered_bookmarkables = []
    Bookmark.register_bookmarkable(
      model: Post,
      serializer: UserPostBookmarkSerializer,
      list_query: lambda do |user, guardian|
        topics = Topic.listable_topics.secured(guardian)
        pms = Topic.private_messages_for_user(user)
        post_bookmarks = user
          .bookmarks
          .joins("INNER JOIN posts ON posts.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Post'")
          .joins("LEFT JOIN topics ON topics.id = posts.topic_id")
          .joins("LEFT JOIN topic_users ON topic_users.topic_id = topics.id")
          .where("topic_users.user_id = ?", user.id)
          .where(bookmarkable_type: "Post")
        guardian.filter_allowed_categories(
          post_bookmarks.merge(topics.or(pms)).merge(Post.secured(guardian))
        )
      end,
      search_query: lambda do |bookmarks, query, ts_query, &bookmarkable_search|
        bookmarkable_search.call(
          bookmarks.joins(
            "LEFT JOIN post_search_data ON post_search_data.post_id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Post'"
          ),
          "#{ts_query} @@ post_search_data.search_data"
        )
      end,
      preload_associations: [{ topic: [:topic_users, :tags] }, :user]
    )
    Bookmark.register_bookmarkable(
      model: Topic,
      serializer: UserTopicBookmarkSerializer,
      list_query: lambda do |user, guardian|
        topics = Topic.listable_topics.secured(guardian)
        pms = Topic.private_messages_for_user(user)
        topic_bookmarks = user
          .bookmarks
          .joins("INNER JOIN topics ON topics.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Topic'")
          .joins("LEFT JOIN topic_users ON topic_users.topic_id = topics.id")
          .where("topic_users.user_id = ?", user.id)
          .where(bookmarkable_type: "Topic")
        guardian.filter_allowed_categories(topic_bookmarks.merge(topics.or(pms)))
      end,
      search_query: lambda do |bookmarks, query, ts_query, &bookmarkable_search|
        bookmarkable_search.call(
          bookmarks
          .joins("LEFT JOIN posts ON posts.topic_id = topics.id AND posts.post_number = 1")
          .joins("LEFT JOIN post_search_data ON post_search_data.post_id = posts.id"),
        "#{ts_query} @@ post_search_data.search_data"
        )
      end,
      preload_associations: [:topic_users, :tags, { posts: :user }]
    )
  end
  reset_bookmarkables

  def self.valid_bookmarkable_types
    Bookmark.registered_bookmarkables.map(&:model).map(&:to_s)
  end

  belongs_to :user
  belongs_to :post
  has_one :topic, through: :post
  belongs_to :bookmarkable, polymorphic: true

  # TODO (martin) [POLYBOOK] Not relevant once polymorphic bookmarks are implemented.
  def topic_id
    return if SiteSetting.use_polymorphic_bookmarks
    post.topic_id
  end

  def self.auto_delete_preferences
    @auto_delete_preferences ||= Enum.new(
      never: 0,
      when_reminder_sent: 1,
      on_owner_reply: 2,
      clear_reminder: 3,
    )
  end

  def self.select_type(bookmarks_relation, type)
    bookmarks_relation.select { |bm| bm.bookmarkable_type == type }
  end

  # TODO (martin) [POLYBOOK] Not relevant once polymorphic bookmarks are implemented.
  validate :unique_per_post_for_user,
    on: [:create, :update],
    if: Proc.new { |b| b.will_save_change_to_post_id? || b.will_save_change_to_user_id? }

  # TODO (martin) [POLYBOOK] Not relevant once polymorphic bookmarks are implemented.
  validate :for_topic_must_use_first_post,
    on: [:create, :update],
    if: Proc.new { |b| b.will_save_change_to_post_id? || b.will_save_change_to_for_topic? }

  validate :polymorphic_columns_present, on: [:create, :update]
  validate :valid_bookmarkable_type, on: [:create, :update]

  validate :unique_per_bookmarkable,
    on: [:create, :update],
    if: Proc.new { |b|
      b.will_save_change_to_bookmarkable_id? || b.will_save_change_to_bookmarkable_type? || b.will_save_change_to_user_id?
    }

  validate :ensure_sane_reminder_at_time, if: :will_save_change_to_reminder_at?
  validate :bookmark_limit_not_reached
  validates :name, length: { maximum: 100 }

  def polymorphic_columns_present
    return if !SiteSetting.use_polymorphic_bookmarks
    return if self.bookmarkable_id.present? && self.bookmarkable_type.present?

    self.errors.add(:base, I18n.t("bookmarks.errors.bookmarkable_id_type_required"))
  end

  def unique_per_bookmarkable
    return if !SiteSetting.use_polymorphic_bookmarks
    return if !Bookmark.exists?(user_id: user_id, bookmarkable_id: bookmarkable_id, bookmarkable_type: bookmarkable_type)

    self.errors.add(:base, I18n.t("bookmarks.errors.already_bookmarked", type: bookmarkable_type))
  end

  # TODO (martin) [POLYBOOK] Not relevant once polymorphic bookmarks are implemented.
  def unique_per_post_for_user
    return if SiteSetting.use_polymorphic_bookmarks

    exists = if is_for_first_post?
      Bookmark.exists?(user_id: user_id, post_id: post_id, for_topic: for_topic)
    else
      Bookmark.exists?(user_id: user_id, post_id: post_id)
    end

    if exists
      self.errors.add(:base, I18n.t("bookmarks.errors.already_bookmarked_post"))
    end
  end

  # TODO (martin) [POLYBOOK] Not relevant once polymorphic bookmarks are implemented.
  def for_topic_must_use_first_post
    if !is_for_first_post? && self.for_topic
      self.errors.add(:base, I18n.t("bookmarks.errors.for_topic_must_use_first_post"))
    end
  end

  def ensure_sane_reminder_at_time
    return if reminder_at.blank?
    if reminder_at < Time.zone.now
      self.errors.add(:base, I18n.t("bookmarks.errors.cannot_set_past_reminder"))
    end
    if reminder_at > 10.years.from_now.utc
      self.errors.add(:base, I18n.t("bookmarks.errors.cannot_set_reminder_in_distant_future"))
    end
  end

  def bookmark_limit_not_reached
    return if user.bookmarks.count < SiteSetting.max_bookmarks_per_user
    return if !new_record?

    self.errors.add(
      :base,
      I18n.t(
        "bookmarks.errors.too_many",
        user_bookmarks_url: "#{Discourse.base_url}/my/activity/bookmarks",
        limit: SiteSetting.max_bookmarks_per_user
      )
    )
  end

  def valid_bookmarkable_type
    return if !SiteSetting.use_polymorphic_bookmarks
    return if Bookmark.valid_bookmarkable_types.include?(self.bookmarkable_type)

    self.errors.add(:base, I18n.t("bookmarks.errors.invalid_bookmarkable", type: self.bookmarkable_type))
  end

  # TODO (martin) [POLYBOOK] Not relevant once polymorphic bookmarks are implemented.
  def is_for_first_post?
    @is_for_first_post ||= new_record? ? Post.exists?(id: post_id, post_number: 1) : post.post_number == 1
  end

  def auto_delete_when_reminder_sent?
    self.auto_delete_preference == Bookmark.auto_delete_preferences[:when_reminder_sent]
  end

  # TODO (martin) [POLYBOOK] This is only relevant for post/topic bookmarkables, need to
  # think of a way to do this gracefully.
  def auto_delete_on_owner_reply?
    self.auto_delete_preference == Bookmark.auto_delete_preferences[:on_owner_reply]
  end

  def auto_clear_reminder_when_reminder_sent?
    self.auto_delete_preference == Bookmark.auto_delete_preferences[:clear_reminder]
  end

  def reminder_at_ics(offset: 0)
    (reminder_at + offset).strftime(I18n.t("datetime_formats.formats.calendar_ics"))
  end

  def clear_reminder!
    update!(
      reminder_last_sent_at: Time.zone.now,
      reminder_set_at: nil,
    )
  end

  scope :with_reminders, -> do
    where("reminder_at IS NOT NULL")
  end

  scope :pending_reminders, ->(before_time = Time.now.utc) do
    with_reminders.where("reminder_at <= ?", before_time).where(reminder_last_sent_at: nil)
  end

  scope :pending_reminders_for_user, ->(user) do
    pending_reminders.where(user: user)
  end

  scope :for_user_in_topic, ->(user_id, topic_id) {
    if SiteSetting.use_polymorphic_bookmarks
      joins("LEFT JOIN posts ON posts.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Post'")
        .joins("LEFT JOIN topics ON topics.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Topic'")
        .where(
          "bookmarks.user_id = :user_id AND (topics.id = :topic_id OR posts.topic_id = :topic_id)",
          user_id: user_id, topic_id: topic_id
        )
    else
      joins(:post).where(user_id: user_id, posts: { topic_id: topic_id })
    end
  }

  def self.find_for_topic_by_user(topic_id, user_id)
    if SiteSetting.use_polymorphic_bookmarks
      find_by(user_id: user_id, bookmarkable_id: topic_id, bookmarkable_type: "Topic")
    else
      for_user_in_topic(user_id, topic_id).where(for_topic: true).first
    end
  end

  def self.count_per_day(opts = nil)
    opts ||= {}
    result = where('bookmarks.created_at >= ?', opts[:start_date] || (opts[:since_days_ago] || 30).days.ago)

    if opts[:end_date]
      result = result.where('bookmarks.created_at <= ?', opts[:end_date])
    end

    if opts[:category_id]
      result = result.joins(:topic).merge(Topic.in_category_and_subcategories(opts[:category_id]))
    end

    result.group('date(bookmarks.created_at)')
      .order('date(bookmarks.created_at)')
      .count
  end

  ##
  # Deletes bookmarks that are attached to posts/topics that were deleted
  # more than X days ago. We don't delete bookmarks instantly when a post/topic
  # is deleted so that there is a grace period to un-delete.
  def self.cleanup!
    grace_time = 3.days.ago
    topics_deleted = DB.query(<<~SQL, grace_time: grace_time)
      DELETE FROM bookmarks b
      USING topics t, posts p
      WHERE (t.id = p.topic_id AND b.post_id = p.id)
        AND (t.deleted_at < :grace_time OR p.deleted_at < :grace_time)
       RETURNING t.id AS topic_id
    SQL

    topics_deleted_ids = topics_deleted.map(&:topic_id).uniq
    topics_deleted_ids.each do |topic_id|
      Jobs.enqueue(:sync_topic_user_bookmarked, topic_id: topic_id)
    end
  end
end

# == Schema Information
#
# Table name: bookmarks
#
#  id                     :bigint           not null, primary key
#  user_id                :bigint           not null
#  post_id                :bigint
#  name                   :string(100)
#  reminder_at            :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  reminder_last_sent_at  :datetime
#  reminder_set_at        :datetime
#  auto_delete_preference :integer          default(0), not null
#  pinned                 :boolean          default(FALSE)
#  for_topic              :boolean          default(FALSE), not null
#  bookmarkable_id        :integer
#  bookmarkable_type      :string
#
# Indexes
#
#  idx_bookmarks_user_polymorphic_unique                 (user_id,bookmarkable_type,bookmarkable_id) UNIQUE
#  index_bookmarks_on_post_id                            (post_id)
#  index_bookmarks_on_reminder_at                        (reminder_at)
#  index_bookmarks_on_reminder_set_at                    (reminder_set_at)
#  index_bookmarks_on_user_id                            (user_id)
#  index_bookmarks_on_user_id_and_post_id_and_for_topic  (user_id,post_id,for_topic) UNIQUE
#
