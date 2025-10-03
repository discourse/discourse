# frozen_string_literal: true

class Bookmark < ActiveRecord::Base
  DEFAULT_BOOKMARKABLES = [
    RegisteredBookmarkable.new(PostBookmarkable),
    RegisteredBookmarkable.new(TopicBookmarkable),
  ]

  def self.registered_bookmarkables
    Set.new(DEFAULT_BOOKMARKABLES | DiscoursePluginRegistry.bookmarkables)
  end

  def self.registered_bookmarkable_from_type(type)
    begin
      resolved_type = Bookmark.polymorphic_class_for(type).name
      Bookmark.registered_bookmarkables.find { |bm| bm.model.name == resolved_type }

      # If the class cannot be found from the provided type using polymorphic_class_for,
      # then the type is not valid and thus there will not be any registered bookmarkable.
    rescue NameError
    end
  end

  def self.valid_bookmarkable_types
    Bookmark.registered_bookmarkables.map { |bm| bm.model.polymorphic_name }
  end

  belongs_to :user
  belongs_to :bookmarkable, polymorphic: true

  def self.auto_delete_preferences
    @auto_delete_preferences ||=
      Enum.new(never: 0, when_reminder_sent: 1, on_owner_reply: 2, clear_reminder: 3)
  end

  def self.select_type(bookmarks_relation, type)
    bookmarks_relation.select { |bm| bm.bookmarkable_type == type }
  end

  validate :polymorphic_columns_present, on: %i[create update]
  validate :valid_bookmarkable_type, on: %i[create update]

  validate :unique_per_bookmarkable,
           on: %i[create update],
           if:
             Proc.new { |b|
               b.will_save_change_to_bookmarkable_id? || b.will_save_change_to_bookmarkable_type? ||
                 b.will_save_change_to_user_id?
             }

  validate :ensure_sane_reminder_at_time, if: :will_save_change_to_reminder_at?
  validate :bookmark_limit_not_reached
  validates :name, length: { maximum: 100 }

  def registered_bookmarkable
    Bookmark.registered_bookmarkable_from_type(self.bookmarkable_type)
  end

  def polymorphic_columns_present
    return if self.bookmarkable_id.present? && self.bookmarkable_type.present?

    self.errors.add(:base, I18n.t("bookmarks.errors.bookmarkable_id_type_required"))
  end

  def unique_per_bookmarkable
    if !Bookmark.exists?(
         user_id: user_id,
         bookmarkable_id: bookmarkable_id,
         bookmarkable_type: bookmarkable_type,
       )
      return
    end

    self.errors.add(:base, I18n.t("bookmarks.errors.already_bookmarked", type: bookmarkable_type))
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
        limit: SiteSetting.max_bookmarks_per_user,
      ),
    )
  end

  def valid_bookmarkable_type
    return if Bookmark.valid_bookmarkable_types.include?(self.bookmarkable_type)

    self.errors.add(
      :base,
      I18n.t("bookmarks.errors.invalid_bookmarkable", type: self.bookmarkable_type),
    )
  end

  def auto_delete_when_reminder_sent?
    self.auto_delete_preference == Bookmark.auto_delete_preferences[:when_reminder_sent]
  end

  def auto_clear_reminder_when_reminder_sent?
    self.auto_delete_preference == Bookmark.auto_delete_preferences[:clear_reminder]
  end

  def reminder_at_ics(offset: 0)
    (reminder_at + offset).strftime(I18n.t("datetime_formats.formats.calendar_ics"))
  end

  def clear_reminder!(force_clear_reminder_at: false)
    reminder_update_attrs = { reminder_last_sent_at: Time.zone.now, reminder_set_at: nil }

    if self.auto_clear_reminder_when_reminder_sent? || force_clear_reminder_at
      reminder_update_attrs[:reminder_at] = nil
    end

    update!(reminder_update_attrs)
  end

  def reminder_at_in_zone(timezone)
    self.reminder_at.in_time_zone(timezone)
  end

  scope :with_reminders, -> { where("reminder_at IS NOT NULL") }

  scope :pending_reminders,
        ->(before_time = Time.now.utc) do
          with_reminders.where("reminder_at <= ?", before_time).where(reminder_last_sent_at: nil)
        end

  scope :pending_reminders_for_user, ->(user) { pending_reminders.where(user: user) }

  scope :for_user_in_topic,
        ->(user_id, topic_id) do
          joins(
            "LEFT JOIN posts ON posts.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Post'",
          ).joins(
            "LEFT JOIN topics ON (topics.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Topic') OR
             (topics.id = posts.topic_id)",
          ).where(
            "bookmarks.user_id = :user_id AND (topics.id = :topic_id OR posts.topic_id = :topic_id)
        AND posts.deleted_at IS NULL AND topics.deleted_at IS NULL",
            user_id: user_id,
            topic_id: topic_id,
          )
        end

  def self.count_per_day(opts = nil)
    opts ||= {}
    result =
      where(
        "bookmarks.created_at >= ?",
        opts[:start_date] || (opts[:since_days_ago] || 30).days.ago,
      )

    result = result.where("bookmarks.created_at <= ?", opts[:end_date]) if opts[:end_date]

    if opts[:category_id]
      result =
        result
          .joins(
            "LEFT JOIN posts ON posts.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Post'",
          )
          .joins(
            "LEFT JOIN topics ON (topics.id = bookmarks.bookmarkable_id AND bookmarks.bookmarkable_type = 'Topic') OR (topics.id = posts.topic_id)",
          )
          .where("topics.deleted_at IS NULL AND posts.deleted_at IS NULL")
          .merge(Topic.in_category_and_subcategories(opts[:category_id]))
    end

    result.group("date(bookmarks.created_at)").order("date(bookmarks.created_at)").count
  end

  ##
  # Deletes bookmarks that are attached to the bookmarkable records that were deleted
  # more than X days ago. We don't delete bookmarks instantly when trashable bookmarkables
  # are deleted so that there is a grace period to un-delete.
  def self.cleanup!
    Bookmark.registered_bookmarkables.each(&:cleanup_deleted)
  end
end

# == Schema Information
#
# Table name: bookmarks
#
#  id                     :bigint           not null, primary key
#  user_id                :bigint           not null
#  name                   :string(100)
#  reminder_at            :datetime
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  reminder_last_sent_at  :datetime
#  reminder_set_at        :datetime
#  auto_delete_preference :integer          default(0), not null
#  pinned                 :boolean          default(FALSE)
#  bookmarkable_id        :bigint
#  bookmarkable_type      :string
#
# Indexes
#
#  idx_bookmarks_user_polymorphic_unique  (user_id,bookmarkable_type,bookmarkable_id) UNIQUE
#  index_bookmarks_on_reminder_at         (reminder_at)
#  index_bookmarks_on_reminder_set_at     (reminder_set_at)
#  index_bookmarks_on_user_id             (user_id)
#
