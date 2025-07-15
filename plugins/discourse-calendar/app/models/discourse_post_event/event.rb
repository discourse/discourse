# frozen_string_literal: true

module DiscoursePostEvent
  class Event < ActiveRecord::Base
    PUBLIC_GROUP = "trust_level_0"
    MIN_NAME_LENGTH = 5
    MAX_NAME_LENGTH = 255
    self.table_name = "discourse_post_event_events"
    self.ignored_columns = %w[starts_at ends_at]

    has_many :event_dates, dependent: :destroy
    # this is a cross plugin dependency, only called if chat is enabled
    belongs_to :chat_channel, class_name: "Chat::Channel"
    has_many :invitees, foreign_key: :post_id, dependent: :delete_all
    belongs_to :post, foreign_key: :id

    scope :visible, -> { where(deleted_at: nil) }

    after_commit :destroy_topic_custom_field, on: %i[destroy]
    after_commit :create_or_update_event_date, on: %i[create update]
    before_save :chat_channel_sync

    validate :raw_invitees_are_groups
    validates :original_starts_at, presence: true
    validates :name,
              length: {
                in: MIN_NAME_LENGTH..MAX_NAME_LENGTH,
              },
              unless: ->(event) { event.name.blank? }

    validate :raw_invitees_length
    validate :ends_before_start
    validate :allowed_custom_fields

    def self.attributes_protected_by_default
      super - %w[id]
    end

    def destroy_topic_custom_field
      if self.post && self.post.is_first_post?
        TopicCustomField.where(
          topic_id: self.post.topic_id,
          name: TOPIC_POST_EVENT_STARTS_AT,
        ).delete_all

        TopicCustomField.where(
          topic_id: self.post.topic_id,
          name: TOPIC_POST_EVENT_ENDS_AT,
        ).delete_all
      end
    end

    def create_or_update_event_date
      starts_at_changed = saved_change_to_original_starts_at
      ends_at_changed = saved_change_to_original_ends_at

      return if !starts_at_changed && !ends_at_changed

      event_dates.update_all(finished_at: Time.current)
      set_next_date
    end

    def set_next_date
      next_dates = calculate_next_date
      return if !next_dates

      event_dates.create!(
        starts_at: next_dates[:starts_at],
        ends_at: next_dates[:ends_at],
      ) do |event_date|
        if next_dates[:ends_at] && next_dates[:ends_at] < Time.current
          event_date.finished_at = next_dates[:ends_at]
        end
      end

      invitees.where.not(status: Invitee.statuses[:going]).update_all(status: nil, notified: false)

      if !next_dates[:rescheduled]
        notify_invitees!
        notify_missing_invitees!
      end

      publish_update!
    end

    def set_topic_bump
      date = nil

      return if reminders.blank?
      reminders
        .split(",")
        .each do |reminder|
          type, value, unit = reminder.split(".")
          next if type != "bumpTopic" || !validate_reminder_unit(unit)
          date = starts_at - value.to_i.public_send(unit)
          break
        end

      return if date.blank?
      Jobs.enqueue(:discourse_post_event_bump_topic, topic_id: self.post.topic_id, date: date)
    end

    def validate_reminder_unit(input)
      ActiveSupport::Duration::PARTS.any? { |part| part.to_s == input }
    end

    def expired?
      (ends_at || starts_at.end_of_day) <= Time.now
    end

    def starts_at
      event_dates.pending.order(:starts_at).last&.starts_at ||
        event_dates.order(:updated_at, :id).last&.starts_at
    end

    def ends_at
      event_dates.pending.order(:starts_at).last&.ends_at ||
        event_dates.order(:updated_at, :id).last&.ends_at
    end

    def on_going_event_invitees
      return [] if !self.ends_at && self.starts_at < Time.now

      if self.ends_at
        extended_ends_at =
          self.ends_at + SiteSetting.discourse_post_event_edit_notifications_time_extension.minutes
        return [] if !(self.starts_at..extended_ends_at).cover?(Time.now)
      end

      invitees.where(status: DiscoursePostEvent::Invitee.statuses[:going])
    end

    def raw_invitees_length
      if self.raw_invitees && self.raw_invitees.length > 10
        errors.add(
          :base,
          I18n.t("discourse_post_event.errors.models.event.raw_invitees_length", count: 10),
        )
      end
    end

    def raw_invitees_are_groups
      if self.raw_invitees && User.select(:id).where(username: self.raw_invitees).limit(1).count > 0
        errors.add(
          :base,
          I18n.t("discourse_post_event.errors.models.event.raw_invitees.only_group"),
        )
      end
    end

    def ends_before_start
      if self.original_starts_at && self.original_ends_at &&
           self.original_starts_at >= self.original_ends_at
        errors.add(
          :base,
          I18n.t("discourse_post_event.errors.models.event.ends_at_before_starts_at"),
        )
      end
    end

    def allowed_custom_fields
      allowed_custom_fields = SiteSetting.discourse_post_event_allowed_custom_fields.split("|")
      self.custom_fields.each do |key, value|
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
        { post_id: self.id, created_at: timestamp, updated_at: timestamp }.merge(attr)
      end
      result = self.invitees.insert_all!(attrs)

      # batch event does not call calleback
      ChatChannelSync.sync(self) if chat_enabled?

      result
    end

    def notify_invitees!(predefined_attendance: false)
      self
        .invitees
        .where(notified: false)
        .find_each do |invitee|
          create_notification!(
            invitee.user,
            self.post,
            predefined_attendance: predefined_attendance,
          )
          invitee.update!(notified: true)
        end
    end

    def notify_missing_invitees!
      self.missing_users.each { |user| create_notification!(user, self.post) } if self.private?
    end

    def create_notification!(user, post, predefined_attendance: false)
      return if post.event.starts_at < Time.current

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
          topic_title: self.name || post.topic.title,
          display_username: post.user.username,
          message: message,
        }.to_json,
      }

      user.notifications.consolidate_or_create!(attrs)
    end

    def ongoing?
      return false if self.closed || self.expired?
      finishes_at = self.ends_at || self.starts_at.end_of_day
      (self.starts_at..finishes_at).cover?(Time.now)
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
      going = self.invitees.order(%i[status user_id]).limit(limit)

      if self.private? && going.count < limit
        # invitees are only created when an attendance is set
        # so we create a dummy invitee object with only what's needed for serializer
        going =
          going +
            missing_users(going.pluck(:user_id))
              .limit(limit - going.count)
              .map { |user| Invitee.new(user: user, post_id: self.id) }
      end

      going
    end

    def publish_update!
      self.post.publish_message!("/discourse-post-event/#{self.post.topic_id}", id: self.id)
    end

    def fetch_users
      @fetched_users ||= Invitee.extract_uniq_usernames(self.raw_invitees)
    end

    def enforce_private_invitees!
      self.invitees.where.not(user_id: fetch_users.select(:id)).delete_all
    end

    def can_user_update_attendance(user)
      return false if self.closed || self.expired?
      return true if self.public?

      self.private? &&
        (
          self.invitees.exists?(user_id: user.id) ||
            (user.groups.pluck(:name) & self.raw_invitees).any?
        )
    end

    def self.update_from_raw(post)
      events = DiscoursePostEvent::EventParser.extract_events(post)

      if events.present?
        event_params = events.first
        event = post.event || DiscoursePostEvent::Event.new(id: post.id)

        tz = ActiveSupport::TimeZone[event_params[:timezone] || "UTC"]
        parsed_starts_at = tz.parse(event_params[:start])
        parsed_ends_at = event_params[:end] ? tz.parse(event_params[:end]) : nil
        parsed_recurrence_until =
          event_params[:"recurrence-until"] ? tz.parse(event_params[:"recurrence-until"]) : nil

        params = {
          name: event_params[:name],
          original_starts_at: parsed_starts_at,
          original_ends_at: parsed_ends_at,
          url: event_params[:url],
          description: event_params[:description],
          location: event_params[:location],
          recurrence: event_params[:recurrence],
          recurrence_until: parsed_recurrence_until,
          timezone: event_params[:timezone],
          show_local_time: event_params[:"show-local-time"] == "true",
          status: Event.statuses[event_params[:status]&.to_sym] || event.status,
          reminders: event_params[:reminders],
          raw_invitees: event_params[:"allowed-groups"]&.split(","),
          minimal: event_params[:minimal],
          closed: event_params[:closed] || false,
          chat_enabled: event_params[:"chat-enabled"]&.downcase == "true",
        }

        params[:custom_fields] = {}
        SiteSetting
          .discourse_post_event_allowed_custom_fields
          .split("|")
          .each do |setting|
            if event_params[setting.to_sym].present?
              params[:custom_fields][setting] = event_params[setting.to_sym]
            end
          end

        event.update_with_params!(params)
        event.set_topic_bump
      elsif post.event
        post.event.destroy!
      end
    end

    def missing_users(excluded_ids = self.invitees.select(:user_id))
      users = User.real.activated.not_silenced.not_suspended.not_staged

      if self.raw_invitees.present?
        user_ids =
          users
            .joins(:groups)
            .where("groups.name" => self.raw_invitees)
            .where.not(id: excluded_ids)
            .select(:id)
        User.where(id: user_ids)
      else
        users.where.not(id: excluded_ids)
      end
    end

    def update_with_params!(params)
      case params[:status] ? params[:status].to_i : self.status
      when Event.statuses[:private]
        if params.key?(:raw_invitees)
          params = params.merge(raw_invitees: Array(params[:raw_invitees]) - [PUBLIC_GROUP])
        else
          params = params.merge(raw_invitees: Array(self.raw_invitees) - [PUBLIC_GROUP])
        end
        self.update!(params)
        self.enforce_private_invitees!
      when Event.statuses[:public]
        self.update!(params.merge(raw_invitees: [PUBLIC_GROUP]))
      when Event.statuses[:standalone]
        self.update!(params.merge(raw_invitees: []))
        self.invitees.destroy_all
      end

      self.publish_update!
    end

    def chat_channel_sync
      if self.chat_enabled && self.chat_channel_id.blank? && post.last_editor_id.present?
        DiscoursePostEvent::ChatChannelSync.sync(
          self,
          guardian: Guardian.new(User.find_by(id: post.last_editor_id)),
        )
      end
    end

    def calculate_next_date
      if self.recurrence.blank? || original_starts_at > Time.current
        return { starts_at: original_starts_at, ends_at: original_ends_at, rescheduled: false }
      end

      next_starts_at =
        RRuleGenerator.generate(
          starts_at: original_starts_at.in_time_zone(timezone),
          timezone:,
          recurrence:,
          recurrence_until:,
        ).first

      if original_ends_at
        difference = original_ends_at - original_starts_at
        next_ends_at = next_starts_at + difference.seconds
      else
        next_ends_at = nil
      end

      { starts_at: next_starts_at, ends_at: next_ends_at, rescheduled: true }
    end
  end
end

# == Schema Information
#
# Table name: discourse_post_event_events
#
#  id                 :bigint           not null, primary key
#  status             :integer          default(0), not null
#  original_starts_at :datetime         not null
#  original_ends_at   :datetime
#  deleted_at         :datetime
#  raw_invitees       :string           is an Array
#  name               :string
#  url                :string(1000)
#  description        :string(1000)
#  location           :string(1000)
#  custom_fields      :jsonb            not null
#  reminders          :string
#  recurrence         :string
#  timezone           :string
#  minimal            :boolean
#  closed             :boolean          default(FALSE), not null
#  chat_enabled       :boolean          default(FALSE), not null
#  chat_channel_id    :bigint
#  recurrence_until   :datetime
#  show_local_time    :boolean          default(FALSE), not null
#
