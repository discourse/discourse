# frozen_string_literal: true

class Notification < ActiveRecord::Base
  attr_accessor :acting_user
  attr_accessor :acting_username

  belongs_to :user
  belongs_to :topic

  has_one :shelved_notification

  MEMBERSHIP_REQUEST_CONSOLIDATION_WINDOW_HOURS = 24

  validates_presence_of :data
  validates_presence_of :notification_type

  scope :read, -> { where(read: true) }
  scope :unread, -> { where(read: false) }
  scope :visible,
        -> do
          joins("LEFT JOIN topics ON notifications.topic_id = topics.id").where(
            "notifications.topic_id IS NULL OR (topics.id IS NOT NULL AND topics.deleted_at IS NULL)",
          )
        end
  scope :prioritized,
        ->(deprioritized_types = []) do
          low_pri =
            "AND notifications.notification_type NOT IN (#{deprioritized_types.join(",")})" if deprioritized_types.present?

          order <<~SQL
            NOT notifications.read AND notifications.high_priority DESC,
            NOT notifications.read #{low_pri || ""} DESC,
            notifications.created_at DESC
          SQL
        end
  scope :for_user_menu, ->(limit) { visible.prioritized.includes(:topic).limit(limit) }

  attr_accessor :skip_send_email

  after_commit :refresh_notification_count, on: %i[create update destroy]
  after_commit :send_email, on: :create

  after_commit(on: :create) { DiscourseEvent.trigger(:notification_created, self) }

  before_create do
    # if we have manually set the notification to high_priority on create then
    # make sure that is respected
    self.high_priority ||= Notification.high_priority_types.include?(self.notification_type)
  end

  def self.consolidate_or_create!(notification_params)
    notification = new(notification_params)
    consolidation_planner = Notifications::ConsolidationPlanner.new

    consolidated_notification = consolidation_planner.consolidate_or_save!(notification)

    consolidated_notification == :no_plan ? notification.tap(&:save!) : consolidated_notification
  end

  def self.purge_old!
    return if SiteSetting.max_notifications_per_user == 0

    DB.exec(<<~SQL, SiteSetting.max_notifications_per_user)
      DELETE FROM notifications n1
      USING (
        SELECT * FROM (
          SELECT
            user_id,
            id,
            rank() OVER (PARTITION BY user_id ORDER BY id DESC)
          FROM notifications
        ) AS X
        WHERE rank = ?
      ) n2
      WHERE n1.user_id = n2.user_id AND n1.id < n2.id
    SQL
  end

  def self.ensure_consistency!
    DB.exec(<<~SQL)
      DELETE
        FROM notifications n
       WHERE high_priority
         AND n.topic_id IS NOT NULL
         AND NOT EXISTS (
            SELECT 1
              FROM posts p
              JOIN topics t ON t.id = p.topic_id
             WHERE p.deleted_at IS NULL
               AND t.deleted_at IS NULL
               AND p.post_number = n.post_number
               AND t.id = n.topic_id
          )
    SQL
  end

  def self.types
    @types ||=
      Enum.new(
        mentioned: 1,
        replied: 2,
        quoted: 3,
        edited: 4,
        liked: 5,
        private_message: 6,
        invited_to_private_message: 7,
        invitee_accepted: 8,
        posted: 9,
        moved_post: 10,
        linked: 11,
        granted_badge: 12,
        invited_to_topic: 13,
        custom: 14,
        group_mentioned: 15,
        group_message_summary: 16,
        watching_first_post: 17,
        topic_reminder: 18,
        liked_consolidated: 19,
        post_approved: 20,
        code_review_commit_approved: 21,
        membership_request_accepted: 22,
        membership_request_consolidated: 23,
        bookmark_reminder: 24,
        reaction: 25,
        votes_released: 26,
        event_reminder: 27,
        event_invitation: 28,
        chat_mention: 29,
        chat_message: 30,
        chat_invitation: 31,
        chat_group_mention: 32, # March 2022 - This is obsolete, as all chat_mentions use `chat_mention` type
        chat_quoted: 33,
        assigned: 34,
        question_answer_user_commented: 35, # Used by https://github.com/discourse/discourse-question-answer
        watching_category_or_tag: 36,
        new_features: 37,
        admin_problems: 38,
        linked_consolidated: 39,
        following: 800, # Used by https://github.com/discourse/discourse-follow
        following_created_topic: 801, # Used by https://github.com/discourse/discourse-follow
        following_replied: 802, # Used by https://github.com/discourse/discourse-follow
        circles_activity: 900, # Used by https://github.com/discourse/discourse-circles
      )
  end

  def self.high_priority_types
    @high_priority_types ||= [types[:private_message], types[:bookmark_reminder]]
  end

  def self.normal_priority_types
    @normal_priority_types ||= types.values - high_priority_types
  end

  def self.read!(user, id: nil, ids: nil, types: nil, topic_id: nil, post_numbers: nil)
    query = user.notifications.unread
    query = query.where(id: id) if id.present?
    query = query.where(id: ids) if ids.present?
    query = query.where(notification_type: types) if types.present?

    if topic_id.present? && post_numbers.present?
      query = query.where(topic_id: topic_id, post_number: post_numbers)
    end

    query.update_all(read: true)
  end

  # Clean up any notifications the user can no longer see.
  # For example, if a topic was previously public then turns private.
  def self.remove_for(user_id, topic_id)
    Notification.where(user_id: user_id, topic_id: topic_id).delete_all
  end

  def self.filter_inaccessible_topic_notifications(guardian, notifications)
    topic_ids = notifications.map(&:topic_id).compact.uniq
    accessible_topic_ids = guardian.can_see_topic_ids(topic_ids:)
    notifications.select { |n| n.topic_id.blank? || accessible_topic_ids.include?(n.topic_id) }
  end

  # Be wary of calling this frequently. O(n) JSON parsing can suck.
  def data_hash
    @data_hash ||=
      begin
        return {} if data.blank?

        parsed = JSON.parse(data)
        return {} if parsed.blank?

        parsed.with_indifferent_access
      end
  end

  def url
    topic.relative_url(post_number) if topic.present?
  end

  def post
    return if topic_id.blank? || post_number.blank?
    Post.find_by(topic_id: topic_id, post_number: post_number)
  end

  # Update `index_notifications_user_menu_ordering_deprioritized_likes` index when updating this as this is used by
  # `Notification.prioritized_list` to deprioritize like typed notifications. Also See
  # `db/migrate/20240306063428_add_indexes_to_notifications.rb`.
  def self.like_types
    @@like_types ||= [
      Notification.types[:liked],
      Notification.types[:liked_consolidated],
      Notification.types[:reaction],
    ]
  end

  def self.never = UserOption.like_notification_frequency_type[:never]

  def self.prioritized_list(user, count: 30, types: [])
    return Notification.none unless user&.user_option

    notifications = user.notifications.includes(:topic).visible.limit(count)

    if types.present?
      notifications = notifications.prioritized.where(notification_type: types)
    else
      notifications = notifications.prioritized(like_types)
      if user.user_option.like_notification_frequency == never
        notifications = notifications.where.not(notification_type: like_types)
      end
    end

    notifications
  end

  USERNAME_FIELDS ||= %i[username display_username mentioned_by_username invited_by_username]

  def self.populate_acting_user(notifications)
    usernames =
      notifications.filter_map do |n|
        n.acting_username = n.data_hash.values_at(*USERNAME_FIELDS).compact.first&.downcase
      end

    users = User.where(username_lower: usernames.uniq).index_by(&:username_lower)

    notifications.each { |n| n.acting_user = users[n.acting_username] }

    notifications
  end

  def unread_high_priority?
    self.high_priority? && !read
  end

  def post_id
    Post.where(topic: topic_id, post_number: post_number).pick(:id)
  end

  protected

  def refresh_notification_count
    User.find_by(id: user_id)&.publish_notifications_state if user_id
  end

  def send_email
    return if skip_send_email

    if user.do_not_disturb?
      ShelvedNotification.create(notification_id: self.id)
    else
      NotificationEmailer.process_notification(self)
    end
  end
end

# == Schema Information
#
# Table name: notifications
#
#  id                :integer          not null, primary key
#  notification_type :integer          not null
#  user_id           :integer          not null
#  data              :string(1000)     not null
#  read              :boolean          default(FALSE), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  topic_id          :integer
#  post_number       :integer
#  post_action_id    :integer
#  high_priority     :boolean          default(FALSE), not null
#
# Indexes
#
#  idx_notifications_speedup_unread_count                       (user_id,notification_type) WHERE (NOT read)
#  index_notifications_on_post_action_id                        (post_action_id)
#  index_notifications_on_topic_id_and_post_number              (topic_id,post_number)
#  index_notifications_on_user_id_and_created_at                (user_id,created_at)
#  index_notifications_on_user_id_and_topic_id_and_post_number  (user_id,topic_id,post_number)
#  index_notifications_read_or_not_high_priority                (user_id,id DESC,read,topic_id) WHERE (read OR (high_priority = false))
#  index_notifications_unique_unread_high_priority              (user_id,id) UNIQUE WHERE ((NOT read) AND (high_priority = true))
#  index_notifications_user_menu_ordering                       (user_id, ((high_priority AND (NOT read))) DESC, ((NOT read)) DESC, created_at DESC)
#  index_notifications_user_menu_ordering_deprioritized_likes   (user_id, ((high_priority AND (NOT read))) DESC, (((NOT read) AND (notification_type <> ALL (ARRAY[5, 19, 25])))) DESC, created_at DESC)
#
