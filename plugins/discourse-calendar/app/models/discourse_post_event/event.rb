# frozen_string_literal: true

module DiscoursePostEvent
  class Event < ActiveRecord::Base
    PUBLIC_GROUP = "trust_level_0"
    MIN_NAME_LENGTH = 5
    MAX_NAME_LENGTH = 255
    MAX_DESCRIPTION_LENGTH = 1000
    DEFAULT_TIMEZONE = "UTC"

    self.table_name = "discourse_post_event_events"
    self.ignored_columns = %w[starts_at ends_at]

    has_many :event_dates, dependent: :destroy
    # this is a cross plugin dependency, only called if chat is enabled
    belongs_to :chat_channel, class_name: "Chat::Channel"
    has_many :invitees, foreign_key: :post_id, dependent: :delete_all
    belongs_to :post, foreign_key: :id
    belongs_to :image_upload, class_name: "Upload", optional: true
    has_many :upload_references, as: :target, dependent: :destroy

    scope :visible, -> { where(deleted_at: nil) }
    scope :open, -> { where(closed: false) }

    before_save :chat_channel_sync
    # prepend so it runs before `dependent: :delete_all` wipes the invitees
    before_destroy :reset_invitees_topic_tracking, prepend: true
    after_commit :create_livestream_chat_channel, on: %i[create update]
    after_commit :warm_livestream_onebox, on: %i[create update]
    after_commit :destroy_topic_custom_field, on: %i[destroy]
    after_commit :create_or_update_event_date, on: %i[create update]
    after_save do
      if saved_change_to_image_upload_id?
        UploadReference.ensure_exist!(upload_ids: [image_upload_id], target: self)
      end
    end

    validate :raw_invitees_are_groups
    validates :original_starts_at, presence: true
    validates :name,
              length: {
                in: MIN_NAME_LENGTH..MAX_NAME_LENGTH,
              },
              unless: ->(event) { event.name.blank? }
    validates :description, length: { maximum: MAX_DESCRIPTION_LENGTH }
    validates :max_attendees, numericality: { only_integer: true, greater_than: 0, allow_nil: true }

    validate :raw_invitees_length
    validate :ends_before_start
    validate :allowed_custom_fields

    def self.attributes_protected_by_default
      super - %w[id]
    end

    def create_livestream_chat_channel
      return unless livestream?
      DiscourseCalendar::Livestream.handle_topic_chat_channel_creation(post.topic)
    end

    def warm_livestream_onebox
      return if !livestream? || location.blank?
      return if !saved_change_to_livestream? && !saved_change_to_location?
      return if Oneboxer.cached_onebox(location).present?

      Jobs.enqueue(:warm_livestream_onebox, event_id: id, url: location)
    end

    def destroy_topic_custom_field
      if post && post.is_first_post?
        TopicCustomField.where(topic_id: post.topic_id, name: TOPIC_POST_EVENT_STARTS_AT).delete_all

        TopicCustomField.where(topic_id: post.topic_id, name: TOPIC_POST_EVENT_ENDS_AT).delete_all

        TopicCustomField.where(topic_id: post.topic_id, name: TOPIC_POST_EVENT_ALL_DAY).delete_all
      end
    end

    def create_or_update_event_date
      starts_at_changed = saved_change_to_original_starts_at
      ends_at_changed = saved_change_to_original_ends_at

      return if !starts_at_changed && !ends_at_changed

      set_next_date
    end

    def set_next_date
      return if closed

      next_date_result = calculate_next_date

      return event_dates.update_all(finished_at: Time.current) if next_date_result.nil?

      starts_at, ends_at = next_date_result
      finish_previous_event_dates(starts_at) if dates_changed?
      upsert_event_date(starts_at, ends_at)
      reset_invitee_notifications
      notify_if_new_event
      publish_update!
    end

    def set_topic_bump
      return if closed

      date = nil

      return if reminders.blank? || starts_at.nil?
      reminders
        .split(",")
        .each do |reminder|
          type, value, unit = reminder.split(".")
          next if type != "bumpTopic" || !validate_reminder_unit(unit)
          date = starts_at - value.to_i.public_send(unit)
          break
        end

      return if date.blank?
      Jobs.enqueue(:discourse_post_event_bump_topic, topic_id: post.topic_id, date: date.iso8601)
    end

    def validate_reminder_unit(input)
      ActiveSupport::Duration::PARTS.any? { |part| part.to_s == input }
    end

    def expired?
      if recurring?
        return false if recurrence_until.nil?
        return Time.current > recurrence_until
      end

      return true if starts_at.nil?
      (ends_at || starts_at.end_of_day) <= Time.now
    end

    def starts_at
      return nil if recurring? && recurrence_until.present? && recurrence_until < Time.current
      current_event_date&.starts_at || original_starts_at
    end

    def ends_at
      return nil if recurring? && recurrence_until.present? && recurrence_until < Time.current
      current_event_date&.ends_at || original_ends_at
    end

    def current_event_date
      if association(:event_dates).loaded?
        pending = event_dates.select { |d| d.finished_at.nil? }
        pending.max_by(&:starts_at) || event_dates.max_by { |d| [d.updated_at, d.id] }
      else
        event_dates.current_first.first
      end
    end

    def on_going_event_invitees
      return [] if starts_at.nil? # Can't determine ongoing status without start time
      if !ends_at && starts_at < Time.now && (!all_day || starts_at.end_of_day <= Time.now)
        return []
      end

      if ends_at
        extended_ends_at =
          ends_at + SiteSetting.discourse_post_event_edit_notifications_time_extension.minutes
        return [] if !(starts_at..extended_ends_at).cover?(Time.now)
      end

      invitees.where(status: DiscoursePostEvent::Invitee.statuses[:going])
    end

    def raw_invitees_length
      if raw_invitees && raw_invitees.length > 10
        errors.add(
          :base,
          I18n.t("discourse_post_event.errors.models.event.raw_invitees_length", count: 10),
        )
      end
    end

    def raw_invitees_are_groups
      return if raw_invitees.blank?

      non_group_invitees = raw_invitees - Group.where(name: raw_invitees).pluck(:name)
      return if non_group_invitees.blank?

      if User.where(username: non_group_invitees).exists?
        errors.add(
          :base,
          I18n.t("discourse_post_event.errors.models.event.raw_invitees.only_group"),
        )
      end
    end

    def ends_before_start
      if original_starts_at && original_ends_at && original_starts_at >= original_ends_at
        errors.add(
          :base,
          I18n.t("discourse_post_event.errors.models.event.ends_at_before_starts_at"),
        )
      end
    end

    def allowed_custom_fields
      allowed_custom_fields = SiteSetting.discourse_post_event_allowed_custom_fields.split("|")
      custom_fields.each do |key, value|
        if !allowed_custom_fields.include?(key)
          errors.add(
            :base,
            I18n.t("discourse_post_event.errors.models.event.custom_field_is_invalid", field: key),
          )
        end
      end
    end

    def create_invitees(attrs)
      timestamp = Time.now
      attrs.map! do |attr|
        { post_id: id, created_at: timestamp, updated_at: timestamp }.merge(attr)
      end
      result = invitees.insert_all!(attrs)

      # batch event does not call callback
      ChatChannelSync.sync(self) if chat_enabled?

      result
    end

    def notify_invitees!(predefined_attendance: false)
      invitees
        .where(notified: false)
        .find_each do |invitee|
          create_notification!(invitee.user, post, predefined_attendance: predefined_attendance)
          invitee.update!(notified: true)
        end
    end

    def notify_missing_invitees!
      missing_users.each { |user| create_notification!(user, post) } if private?
    end

    def create_notification!(user, post, predefined_attendance: false)
      return if post.event.starts_at.nil? || post.event.starts_at < Time.current
      return if !Guardian.new(user).can_see?(post)

      message =
        if predefined_attendance
          "discourse_post_event.notifications.invite_user_predefined_attendance_notification"
        else
          "discourse_post_event.notifications.invite_user_notification"
        end

      attrs = {
        notification_type: Notification.types[:event_invitation] || Notification.types[:custom],
        topic_id: post.topic_id,
        post_number: post.post_number,
        data: {
          user_id: user.id,
          topic_title: name || post.topic.title,
          display_username: post.user.username,
          message: message,
          event_name: name,
        }.to_json,
      }

      user.notifications.consolidate_or_create!(attrs)
    end

    def ongoing?
      return false if closed || expired? || starts_at.nil?
      finishes_at = ends_at || starts_at.end_of_day
      (starts_at..finishes_at).cover?(Time.now)
    end

    def going_count
      invitees.where(status: Invitee.statuses[:going]).count
    end

    def at_capacity?
      return false if max_attendees.blank?
      going_count >= max_attendees
    end

    def self.statuses
      @statuses ||= Enum.new(standalone: 0, public: 1, private: 2)
    end

    def public?
      status == Event.statuses[:public]
    end

    def standalone?
      status == Event.statuses[:standalone]
    end

    def private?
      status == Event.statuses[:private]
    end

    def recurring?
      recurrence.present?
    end

    def most_likely_going(limit = SiteSetting.displayed_invitees_limit)
      going = invitees.order(%i[status created_at user_id]).limit(limit)

      if private? && going.count < limit
        # invitees are only created when an attendance is set
        # so we create a dummy invitee object with only what's needed for serializer
        going =
          going +
            missing_users(going.pluck(:user_id))
              .limit(limit - going.count)
              .map { |user| Invitee.new(user: user, post_id: id) }
      end

      going
    end

    def publish_update!
      post.publish_message!("/discourse-post-event/#{post.topic_id}", id: id)
    end

    def fetch_users
      @fetched_users ||= Invitee.extract_uniq_usernames(raw_invitees)
    end

    def enforce_private_invitees!
      pruned = invitees.where.not(user_id: fetch_users.select(:id))
      pruned_user_ids = pruned.pluck(:user_id)
      pruned.delete_all
      Invitee.reset_topic_tracking!(user_ids: pruned_user_ids, topic_id: post.topic_id)
      unfollow_livestream_chat(pruned_user_ids)
    end

    # Unfollow users from the livestream chat channel once they are no longer
    # attending (e.g. pruned when a private event's invited groups change). Chat
    # following tracks attendance, so removed attendees should not keep the
    # channel in their chat list.
    def unfollow_livestream_chat(user_ids)
      return if user_ids.blank?

      channel = post.topic.topic_chat_channel&.chat_channel
      return if channel.nil?

      manager = Chat::ChannelMembershipManager.new(channel)
      User
        .where(id: user_ids)
        .find_each do |user|
          membership = manager.unfollow(user)
          next if membership.nil?
          DiscourseCalendar::Livestream.publish_livestream_chat_status(membership, user:)
        end
    end

    def can_user_update_attendance?(user)
      return false if closed || expired?
      return true if public?

      private? &&
        (invitees.exists?(user_id: user.id) || (user.groups.pluck(:name) & raw_invitees).any?)
    end

    def sync_image_to_post_and_topic(generate_thumbnails: false)
      return unless image_upload_id

      post.update_column(:image_upload_id, image_upload_id)
      if post.is_first_post?
        post.topic.update_column(:image_upload_id, image_upload_id)
        if generate_thumbnails
          extra_sizes =
            ThemeModifierHelper.new(
              theme_ids: Theme.user_selectable.pluck(:id),
            ).topic_thumbnail_sizes
          post.topic.generate_thumbnails!(extra_sizes: extra_sizes)
        end
      end
    end

    def self.handle_post_event_webhooks(post, event_before)
      had_event_before = event_before.present?

      if post.event && had_event_before
        WebHook.enqueue_calendar_event_hooks(:calendar_event_updated, post.event)
      elsif post.event && !had_event_before
        WebHook.enqueue_calendar_event_hooks(:calendar_event_created, post.event)
      elsif !post.event && had_event_before
        payload = WebHook.build_calendar_event_payload(event_before)
        WebHook.enqueue_calendar_event_hooks(:calendar_event_destroyed, event_before, payload)
      end
    end

    def missing_users(excluded_ids = invitees.select(:user_id))
      users = User.real.activated.not_silenced.not_suspended.not_staged

      if raw_invitees.present?
        user_ids =
          users
            .joins(:groups)
            .where("groups.name" => raw_invitees)
            .where.not(id: excluded_ids)
            .select(:id)
        User.where(id: user_ids)
      elsif private?
        User.none
      else
        users.where.not(id: excluded_ids)
      end
    end

    SUGGESTED_USERS_LIMIT = 10

    # Users that could be invited to this event, ranked by how closely their
    # username matches +filter+ (exact match first). Already-invited users are
    # excluded, optionally narrowed to a given attendance +type+.
    def suggested_users(filter, type: nil)
      excluded = type ? invitees.with_status(type) : invitees

      missing_users(excluded.select(:user_id))
        .where(
          "LOWER(username) LIKE :filter",
          filter: "%#{User.sanitize_sql_like(filter.downcase)}%",
        )
        .order(
          DB.sql_fragment(
            "CASE WHEN LOWER(username) = ? THEN 0 ELSE 1 END ASC, LOWER(username) ASC",
            filter.downcase,
          ),
        )
        .limit(SUGGESTED_USERS_LIMIT)
    end

    def update_with_params!(params)
      case params[:status] ? params[:status].to_i : status
      when Event.statuses[:private]
        if params.key?(:raw_invitees)
          params = params.merge(raw_invitees: Array(params[:raw_invitees]) - [PUBLIC_GROUP])
        else
          params = params.merge(raw_invitees: Array(raw_invitees) - [PUBLIC_GROUP])
        end
        update!(params)
        enforce_private_invitees!
      when Event.statuses[:public]
        update!(params.merge(raw_invitees: [PUBLIC_GROUP]))
      when Event.statuses[:standalone]
        update!(params.merge(raw_invitees: []))
        invitees.destroy_all
      end

      publish_update!
    end

    def chat_channel_sync
      if chat_enabled && chat_channel_id.blank? && post.last_editor_id.present?
        DiscoursePostEvent::ChatChannelSync.sync(
          self,
          guardian: Guardian.new(User.find_by(id: post.last_editor_id)),
        )
      end
    end

    def calculate_next_date
      if recurrence.blank? || original_starts_at > Time.current
        return original_starts_at, original_ends_at
      end

      next_starts_at = calculate_next_recurring_date
      return nil unless next_starts_at

      event_duration =
        original_ends_at ? original_ends_at - original_starts_at : (all_day ? 86_400 : 3600)
      next_ends_at = next_starts_at + event_duration
      [next_starts_at, next_ends_at]
    end

    def calculate_next_occurrence_from(from_time)
      return nil if recurrence.blank?
      if original_starts_at > from_time
        return { starts_at: original_starts_at, ends_at: original_ends_at }
      end

      next_starts_at = calculate_next_recurring_date_from(from_time)
      return nil unless next_starts_at

      event_duration =
        original_ends_at ? original_ends_at - original_starts_at : (all_day ? 86_400 : 3600)
      next_ends_at = next_starts_at + event_duration
      { starts_at: next_starts_at, ends_at: next_ends_at }
    end

    def duration
      return nil unless original_starts_at

      duration_seconds = original_ends_at ? original_ends_at - original_starts_at : 3600
      hours = (duration_seconds / 3600)
      minutes = ((duration_seconds % 3600) / 60)
      seconds = (duration_seconds % 60)

      sprintf("%02d:%02d:%02d", hours, minutes, seconds)
    end

    def rrule_timezone
      timezone || DEFAULT_TIMEZONE
    end

    private

    def reset_invitees_topic_tracking
      topic_id = post&.topic_id
      return if topic_id.nil?

      Invitee.reset_topic_tracking!(user_ids: invitees.pluck(:user_id), topic_id:)
    end

    def dates_changed?
      saved_change_to_original_starts_at || saved_change_to_original_ends_at
    end

    def finish_previous_event_dates(current_starts_at)
      existing_date = event_dates.find_by(starts_at: current_starts_at)
      event_dates
        .where.not(id: existing_date&.id)
        .where(finished_at: nil)
        .update_all(finished_at: Time.current)
    end

    def upsert_event_date(starts_at, ends_at)
      finished_at = ends_at && ends_at < Time.current ? ends_at : nil

      existing_date = event_dates.find_by(starts_at:)

      if existing_date
        # Only update if something actually changed
        unless existing_date.ends_at == ends_at && existing_date.finished_at == finished_at
          existing_date.update!(ends_at:, finished_at:)
        end
      else
        event_dates.create!(starts_at:, ends_at:, finished_at:)
      end
    end

    def reset_invitee_notifications
      invitees.where(
        "status != :going OR recurring = FALSE",
        going: Invitee.statuses[:going],
      ).update_all(status: nil, notified: false, recurring: false)
    end

    def notify_if_new_event
      is_generating_future_recurrence = recurrence.present? && original_starts_at <= Time.current

      unless is_generating_future_recurrence
        notify_invitees!
        notify_missing_invitees!
      end
    end

    def calculate_next_recurring_date
      timezone_starts_at = original_starts_at.in_time_zone(timezone)
      timezone_recurrence_until = recurrence_until&.in_time_zone(timezone)

      RRuleGenerator.generate(
        starts_at: timezone_starts_at,
        timezone: rrule_timezone,
        recurrence: recurrence,
        recurrence_until: timezone_recurrence_until,
        dtstart: timezone_starts_at,
      ).first
    end

    def calculate_next_recurring_date_from(from_time)
      timezone_starts_at = original_starts_at.in_time_zone(timezone)
      timezone_recurrence_until = recurrence_until&.in_time_zone(timezone)
      from_time_in_tz = from_time.in_time_zone(timezone)

      RRule::Rule
        .new(
          RRuleConfigurator.rule(
            recurrence_until: timezone_recurrence_until,
            recurrence: recurrence,
            starts_at: timezone_starts_at,
          ),
          dtstart: timezone_starts_at,
          tzid: rrule_timezone,
        )
        .between(from_time_in_tz - 1.hour, from_time_in_tz + 1.year)
        .find { |date| date >= from_time_in_tz }
    end
  end
end

# == Schema Information
#
# Table name: discourse_post_event_events
#
#  id                 :bigint           not null, primary key
#  all_day            :boolean          default(FALSE), not null
#  chat_enabled       :boolean          default(FALSE), not null
#  closed             :boolean          default(FALSE), not null
#  custom_fields      :jsonb            not null
#  deleted_at         :datetime
#  description        :string(1000)
#  livestream         :boolean          default(FALSE), not null
#  location           :string(1000)
#  max_attendees      :integer
#  minimal            :boolean
#  name               :string
#  original_ends_at   :datetime
#  original_starts_at :datetime         not null
#  raw_invitees       :string           is an Array
#  recurrence         :string
#  recurrence_until   :datetime
#  reminders          :string
#  show_local_time    :boolean          default(FALSE), not null
#  status             :integer          default(0), not null
#  timezone           :string
#  url                :string(1000)
#  chat_channel_id    :bigint
#  image_upload_id    :bigint
#
# Indexes
#
#  index_discourse_post_event_events_on_image_upload_id  (image_upload_id)
#
