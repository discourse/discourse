# frozen_string_literal: true

class Notification < ActiveRecord::Base
  self.ignored_columns = [
    :old_id, # TODO: Remove once 20240829140226_drop_old_notification_id_columns has been promoted to pre-deploy
  ]

  attr_accessor :acting_user
  attr_accessor :acting_username

  belongs_to :user
  belongs_to :topic

  has_one :shelved_notification

  MEMBERSHIP_REQUEST_CONSOLIDATION_WINDOW_HOURS = 24

  validates_presence_of :data
  validates_presence_of :notification_type

  scope :unread, lambda { where(read: false) }
  scope :recent,
        lambda { |n = nil|
          n ||= 10
          order("notifications.created_at desc").limit(n)
        }
  scope :visible,
        lambda {
          joins("LEFT JOIN topics ON notifications.topic_id = topics.id").where(
            "topics.id IS NULL OR topics.deleted_at IS NULL",
          )
        }
  scope :unread_type, ->(user, type, limit = 30) { unread_types(user, [type], limit) }
  scope :unread_types,
        ->(user, types, limit = 30) do
          where(user_id: user.id, read: false, notification_type: types)
            .visible
            .includes(:topic)
            .limit(limit)
        end
  scope :prioritized,
        ->(deprioritized_types = []) do
          scope = order("notifications.high_priority AND NOT notifications.read DESC")

          if deprioritized_types.present?
            scope =
              scope.order(
                DB.sql_fragment(
                  "NOT notifications.read AND notifications.notification_type NOT IN (?) DESC",
                  deprioritized_types,
                ),
              )
          else
            scope = scope.order("NOT notifications.read DESC")
          end

          scope.order("notifications.created_at DESC")
        end

  scope :for_user_menu,
        ->(user_id, limit: 30) do
          where(user_id: user_id).visible.prioritized.includes(:topic).limit(limit)
        end

  attr_accessor :skip_send_email

  after_commit :refresh_notification_count, on: %i[create update destroy]
  after_commit :send_email, on: :create

  after_commit(on: :create) { DiscourseEvent.trigger(:notification_created, self) }

  before_create do
    # if we have manually set the notification to high_priority on create then
    # make sure that is respected
    self.high_priority =
      self.high_priority || Notification.high_priority_types.include?(self.notification_type)
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
        chat_watched_thread: 40,
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
    @normal_priority_types ||= types.reject { |_k, v| high_priority_types.include?(v) }.values
  end

  def self.mark_posts_read(user, topic_id, post_numbers)
    Notification.where(
      user_id: user.id,
      topic_id: topic_id,
      post_number: post_numbers,
      read: false,
    ).update_all(read: true)
  end

  def self.read(user, notification_ids)
    Notification.where(id: notification_ids, user_id: user.id, read: false).update_all(read: true)
  end

  def self.read_types(user, types = nil)
    query = Notification.where(user_id: user.id, read: false)
    query = query.where(notification_type: types) if types
    query.update_all(read: true)
  end

  def self.interesting_after(min_date)
    result =
      where("created_at > ?", min_date)
        .includes(:topic)
        .visible
        .unread
        .limit(20)
        .order(
          "CASE WHEN notification_type = #{Notification.types[:replied]} THEN 1
                           WHEN notification_type = #{Notification.types[:mentioned]} THEN 2
                           ELSE 3
                      END, created_at DESC",
        )
        .to_a

    # Remove any duplicates by type and topic
    if result.present?
      seen = {}
      to_remove = Set.new

      result.each do |r|
        seen[r.notification_type] ||= Set.new
        if seen[r.notification_type].include?(r.topic_id)
          to_remove << r.id
        else
          seen[r.notification_type] << r.topic_id
        end
      end
      result.reject! { |r| to_remove.include?(r.id) }
    end

    result
  end

  # Clean up any notifications the user can no longer see. For example, if a topic was previously
  # public then turns private.
  def self.remove_for(user_id, topic_id)
    Notification.where(user_id: user_id, topic_id: topic_id).delete_all
  end

  def self.filter_inaccessible_topic_notifications(guardian, notifications)
    topic_ids = notifications.map { |n| n.topic_id }.compact.uniq
    accessible_topic_ids = guardian.can_see_topic_ids(topic_ids: topic_ids)
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
    [
      Notification.types[:liked],
      Notification.types[:liked_consolidated],
      Notification.types[:reaction],
    ]
  end

  def self.prioritized_list(user, count: 30, types: [])
    return [] if !user&.user_option

    notifications =
      user
        .notifications
        .includes(:topic)
        .visible
        .prioritized(types.present? ? [] : like_types)
        .limit(count)

    if types.present?
      notifications = notifications.where(notification_type: types)
    elsif user.user_option.like_notification_frequency ==
          UserOption.like_notification_frequency_type[:never]
      like_types.each do |notification_type|
        notifications = notifications.where("notification_type <> ?", notification_type)
      end
    end
    notifications.to_a
  end

  def self.recent_report(user, count = nil, types = [])
    return unless user && user.user_option

    count ||= 10
    notifications = user.notifications.visible.recent(count).includes(:topic)

    notifications = notifications.where(notification_type: types) if types.present?
    if user.user_option.like_notification_frequency ==
         UserOption.like_notification_frequency_type[:never]
      [
        Notification.types[:liked],
        Notification.types[:liked_consolidated],
      ].each do |notification_type|
        notifications = notifications.where("notification_type <> ?", notification_type)
      end
    end

    notifications = notifications.to_a

    if notifications.present?
      builder = DB.build(<<~SQL)
         SELECT n.id FROM notifications n
         /*where*/
        ORDER BY n.id ASC
        /*limit*/
      SQL

      builder.where(<<~SQL, user_id: user.id)
        n.high_priority = TRUE AND
        n.user_id = :user_id AND
        NOT read
      SQL
      builder.where("notification_type IN (:types)", types: types) if types.present?
      builder.limit(count.to_i)

      ids = builder.query_single

      if ids.length > 0
        notifications +=
          user
            .notifications
            .order("notifications.created_at DESC")
            .where(id: ids)
            .joins(:topic)
            .limit(count)
      end

      notifications
        .uniq(&:id)
        .sort do |x, y|
          if x.unread_high_priority? && !y.unread_high_priority?
            -1
          elsif y.unread_high_priority? && !x.unread_high_priority?
            1
          else
            y.created_at <=> x.created_at
          end
        end
        .take(count)
    else
      []
    end
  end

  def self.populate_acting_user(notifications)
    usernames =
      notifications.map do |notification|
        notification.acting_username =
          (
            notification.data_hash[:username] || notification.data_hash[:display_username] ||
              notification.data_hash[:mentioned_by_username] ||
              notification.data_hash[:invited_by_username] ||
              notification.data_hash[:original_username]
          )&.downcase
      end

    users = User.where(username_lower: usernames.uniq).index_by(&:username_lower)
    notifications.each do |notification|
      notification.acting_user = users[notification.acting_username]
      notification.data_hash[:original_name] = notification.acting_user&.name
    end

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
#  id                :bigint           not null, primary key
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
