# frozen_string_literal: true

class Bookmark < ActiveRecord::Base
  # these columns were here for a very short amount of time,
  # hence the very short ignore time
  self.ignored_columns = [
    "bookmarkable_id", # TODO 2022-04-01 remove
    "bookmarkable_type", # TODO 2022-04-01 remove
    "topic_id", # TODO 2022-04-01: remove
    "reminder_type" # TODO 2021-04-01: remove
  ]

  belongs_to :user
  belongs_to :post
  has_one :topic, through: :post
  belongs_to :bookmarkable, polymorphic: true

  delegate :topic_id, to: :post

  def self.auto_delete_preferences
    @auto_delete_preferences ||= Enum.new(
      never: 0,
      when_reminder_sent: 1,
      on_owner_reply: 2
    )
  end

  validate :unique_per_post_for_user,
    on: [:create, :update],
    if: Proc.new { |b| b.will_save_change_to_post_id? || b.will_save_change_to_user_id? }

  validate :for_topic_must_use_first_post,
    on: [:create, :update],
    if: Proc.new { |b| b.will_save_change_to_post_id? || b.will_save_change_to_for_topic? }

  validate :ensure_sane_reminder_at_time
  validate :bookmark_limit_not_reached
  validates :name, length: { maximum: 100 }

  def unique_per_post_for_user
    exists = if is_for_first_post?
      Bookmark.exists?(user_id: user_id, post_id: post_id, for_topic: for_topic)
    else
      Bookmark.exists?(user_id: user_id, post_id: post_id)
    end

    if exists
      self.errors.add(:base, I18n.t("bookmarks.errors.already_bookmarked_post"))
    end
  end

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

  def is_for_first_post?
    @is_for_first_post ||= new_record? ? Post.exists?(id: post_id, post_number: 1) : post.post_number == 1
  end

  def no_reminder?
    self.reminder_at.blank?
  end

  def auto_delete_when_reminder_sent?
    self.auto_delete_preference == Bookmark.auto_delete_preferences[:when_reminder_sent]
  end

  def auto_delete_on_owner_reply?
    self.auto_delete_preference == Bookmark.auto_delete_preferences[:on_owner_reply]
  end

  def reminder_at_ics(offset: 0)
    (reminder_at + offset).strftime(I18n.t("datetime_formats.formats.calendar_ics"))
  end

  def clear_reminder!
    update!(
      reminder_at: nil,
      reminder_last_sent_at: Time.zone.now,
      reminder_set_at: nil
    )
  end

  scope :with_reminders, -> do
    where("reminder_at IS NOT NULL")
  end

  scope :pending_reminders, ->(before_time = Time.now.utc) do
    with_reminders.where("reminder_at <= :before_time", before_time: before_time)
  end

  scope :pending_reminders_for_user, ->(user) do
    pending_reminders.where(user: user)
  end

  scope :for_user_in_topic, ->(user_id, topic_id) {
    joins(:post).where(user_id: user_id, posts: { topic_id: topic_id })
  }

  def self.find_for_topic_by_user(topic_id, user_id)
    for_user_in_topic(user_id, topic_id).where(for_topic: true).first
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
#  post_id                :bigint           not null
#  name                   :string(100)
#  reminder_at            :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  reminder_last_sent_at  :datetime
#  reminder_set_at        :datetime
#  auto_delete_preference :integer          default(0), not null
#  pinned                 :boolean          default(FALSE)
#  for_topic              :boolean          default(FALSE), not null
#
# Indexes
#
#  index_bookmarks_on_post_id                            (post_id)
#  index_bookmarks_on_reminder_at                        (reminder_at)
#  index_bookmarks_on_reminder_set_at                    (reminder_set_at)
#  index_bookmarks_on_user_id                            (user_id)
#  index_bookmarks_on_user_id_and_post_id_and_for_topic  (user_id,post_id,for_topic) UNIQUE
#
