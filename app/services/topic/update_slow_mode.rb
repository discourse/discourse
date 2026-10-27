# frozen_string_literal: true

class Topic::UpdateSlowMode
  include Service::Base

  MAX_SECONDS = 1.year.to_i

  # @!method self.call(guardian:, params:)
  #   @param [Guardian] guardian
  #   @param [Hash] params
  #   @option params [Integer] :topic_id
  #   @option params [Integer] :seconds 0 turns slow mode off
  #   @option params [String] :enabled_until when slow mode turns itself off: a number of hours,
  #     or a future date and time (UTC unless it says otherwise)
  #   @return [Service::Base::Context]

  params do
    attribute :topic_id, :integer
    attribute :seconds, :integer
    attribute :enabled_until, :string

    attr_reader :ends_at

    # Hours are relative to now, so they're resolved once, before the contract is frozen.
    before_validation { @ends_at = parse_enabled_until if enabling? }

    validates :topic_id, presence: true
    validates :seconds,
              presence: true,
              numericality: {
                greater_than_or_equal_to: 0,
                less_than_or_equal_to: MAX_SECONDS,
              }
    validate :ends_in_the_future, if: -> { enabling? && enabled_until.present? }

    def enabling?
      seconds.to_i.positive?
    end

    private

    def parse_enabled_until
      return if enabled_until.blank?

      hours = Float(enabled_until, exception: false)
      time =
        if hours
          hours.hours.from_now if hours.finite?
        else
          Time.find_zone("UTC").parse(enabled_until)
        end
      # Timers run to the minute, and whole seconds make an unchanged end time compare equal.
      time&.change(usec: 0)
    rescue ArgumentError, RangeError
      nil
    end

    def ends_in_the_future
      if ends_at.nil?
        errors.add(:enabled_until, :invalid)
      elsif ends_at <= Time.zone.now
        errors.add(
          :enabled_until,
          I18n.t("activerecord.errors.models.topic_timer.attributes.execute_at.in_the_past"),
        )
      end
    end
  end

  model :topic
  policy :can_update_slow_mode
  model :slow_mode_timer, optional: true
  model :duplicate_slow_mode_timers, optional: true

  transaction do
    step :update_interval
    only_if(:newly_ending) { step :schedule_end }
    only_if(:already_ending) { step :reschedule_end }
    only_if(:no_longer_ending) { step :cancel_end }
    each(:duplicate_slow_mode_timers) { step :cancel_duplicate_end }
    only_if(:slow_mode_changed) { step :log_slow_mode_change }
  end

  only_if(:slow_mode_set) { step :trigger_slow_mode_set_event }
  only_if(:slow_mode_cleared) { step :trigger_slow_mode_cleared_event }

  private

  def fetch_topic(params:)
    Topic.find_by(id: params.topic_id)
  end

  def can_update_slow_mode(guardian:, topic:)
    guardian.can_moderate?(topic)
  end

  def fetch_slow_mode_timer(topic:)
    topic.topic_timers.where(status_type: TopicTimer.types[:clear_slow_mode]).order(:id).first
  end

  # Private timers are only unique per owner, so a topic can have more than one.
  def fetch_duplicate_slow_mode_timers(topic:, slow_mode_timer:)
    topic
      .topic_timers
      .where(status_type: TopicTimer.types[:clear_slow_mode])
      .where.not(id: slow_mode_timer)
      .to_a
  end

  def update_interval(topic:, params:)
    topic.update!(slow_mode_seconds: params.seconds)
  end

  def newly_ending(params:, slow_mode_timer:)
    params.ends_at.present? && slow_mode_timer.nil?
  end

  def schedule_end(topic:, params:, guardian:)
    topic.topic_timers.create!(
      status_type: TopicTimer.types[:clear_slow_mode],
      execute_at: params.ends_at,
      user: guardian.user,
    )
  end

  def already_ending(params:, slow_mode_timer:)
    params.ends_at.present? && slow_mode_timer.present?
  end

  def reschedule_end(params:, guardian:, slow_mode_timer:)
    slow_mode_timer.update!(execute_at: params.ends_at, acting_user: guardian.user)
  end

  def no_longer_ending(params:, slow_mode_timer:)
    params.ends_at.nil? && slow_mode_timer.present?
  end

  def cancel_end(guardian:, slow_mode_timer:)
    slow_mode_timer.finish!(:cancelled, by_user: guardian.user)
  end

  def cancel_duplicate_end(guardian:, duplicate_slow_mode_timer:)
    duplicate_slow_mode_timer.finish!(:cancelled, by_user: guardian.user)
  end

  def slow_mode_changed(params:, topic:, slow_mode_timer:)
    slow_mode_set(params:, topic:, slow_mode_timer:) || slow_mode_cleared(params:, topic:)
  end

  def log_slow_mode_change(topic:, params:, guardian:)
    StaffActionLogger.new(guardian.user).log_topic_slow_mode(
      topic,
      enabled: params.enabling?,
      seconds: params.seconds,
      until: params.ends_at&.iso8601,
    )
  end

  def slow_mode_set(params:, topic:, slow_mode_timer:)
    return if !params.enabling?

    topic.saved_change_to_slow_mode_seconds? ||
      slow_mode_timer.present? != params.ends_at.present? ||
      slow_mode_timer&.saved_change_to_execute_at?
  end

  def trigger_slow_mode_set_event(topic:, params:, guardian:)
    DiscourseEvent.trigger(:topic_slow_mode_set, topic, params.ends_at, acting_user: guardian.user)
  end

  def slow_mode_cleared(params:, topic:)
    !params.enabling? && topic.saved_change_to_slow_mode_seconds?
  end

  def trigger_slow_mode_cleared_event(topic:, guardian:)
    DiscourseEvent.trigger(:topic_slow_mode_cleared, topic, acting_user: guardian.user)
  end
end
