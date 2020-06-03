# frozen_string_literal: true

class Bookmark < ActiveRecord::Base
  belongs_to :user
  belongs_to :post
  belongs_to :topic

  validates :reminder_at, presence: {
    message: I18n.t("bookmarks.errors.time_must_be_provided"),
    if: -> { reminder_type.present? }
  }

  validate :unique_per_post_for_user
  validate :ensure_sane_reminder_at_time

  # we don't care whether the post or topic is deleted,
  # they hold important information about the bookmark
  def post
    Post.unscoped { super }
  end

  def topic
    Topic.unscoped { super }
  end

  def unique_per_post_for_user
    existing_bookmark = Bookmark.find_by(user_id: user_id, post_id: post_id)
    return if existing_bookmark.blank? || existing_bookmark.id == id
    self.errors.add(:base, I18n.t("bookmarks.errors.already_bookmarked_post"))
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

  def no_reminder?
    self.reminder_at.blank? && self.reminder_type.blank?
  end

  scope :pending_reminders, ->(before_time = Time.now.utc) do
    where("reminder_at IS NOT NULL AND reminder_at <= :before_time", before_time: before_time)
  end

  scope :pending_reminders_for_user, ->(user) do
    pending_reminders.where(user: user)
  end

  def self.reminder_types
    @reminder_type = Enum.new(
      later_today: 1,
      next_business_day: 2,
      tomorrow: 3,
      next_week: 4,
      next_month: 5,
      custom: 6,
      start_of_next_business_week: 7,
      later_this_week: 8
    )
  end

  def self.count_per_day(opts = nil)
    opts ||= {}
    result = where('bookmarks.created_at >= ?', opts[:start_date] || (opts[:since_days_ago] || 30).days.ago)
    result = result.where('bookmarks.created_at <= ?', opts[:end_date]) if opts[:end_date]
    result = result.joins(:topic).merge(Topic.in_category_and_subcategories(opts[:category_id])) if opts[:category_id]
    result.group('date(bookmarks.created_at)')
      .order('date(bookmarks.created_at)')
      .count
  end
end

# == Schema Information
#
# Table name: bookmarks
#
#  id                        :bigint           not null, primary key
#  user_id                   :bigint           not null
#  topic_id                  :bigint           not null
#  post_id                   :bigint           not null
#  name                      :string
#  reminder_type             :integer
#  reminder_at               :datetime
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  reminder_last_sent_at     :datetime
#  reminder_set_at           :datetime
#  delete_when_reminder_sent :boolean          default(FALSE), not null
#
# Indexes
#
#  index_bookmarks_on_post_id              (post_id)
#  index_bookmarks_on_reminder_at          (reminder_at)
#  index_bookmarks_on_reminder_set_at      (reminder_set_at)
#  index_bookmarks_on_reminder_type        (reminder_type)
#  index_bookmarks_on_topic_id             (topic_id)
#  index_bookmarks_on_user_id              (user_id)
#  index_bookmarks_on_user_id_and_post_id  (user_id,post_id) UNIQUE
#
