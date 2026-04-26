# frozen_string_literal: true

module DiscourseSolved::CategoryExtension
  extend ActiveSupport::Concern

  prepended { after_save :reset_accepted_cache, if: -> { SiteSetting.solved_enabled? } }

  def solved_auto_close_hours
    hours = custom_fields["solved_topics_auto_close_hours"].to_i
    [hours, DiscourseSolved::MAX_AUTO_CLOSE_HOURS].min
  end

  def enable_accepted_answers?
    custom_fields[DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD] == "true"
  end

  def enable_accepted_answers=(value)
    custom_fields[DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD] = coerce_boolean_value(
      value,
    )
  end

  def notify_on_staff_accept_solved?
    custom_fields[DiscourseSolved::NOTIFY_ON_STAFF_ACCEPT_SOLVED_CUSTOM_FIELD] == "true"
  end

  def notify_on_staff_accept_solved=(value)
    custom_fields[
      DiscourseSolved::NOTIFY_ON_STAFF_ACCEPT_SOLVED_CUSTOM_FIELD
    ] = coerce_boolean_value(value)
  end

  def empty_box_on_unsolved?
    custom_fields[DiscourseSolved::EMPTY_BOX_ON_UNSOLVED_CUSTOM_FIELD] == "true"
  end

  def empty_box_on_unsolved=(value)
    custom_fields[DiscourseSolved::EMPTY_BOX_ON_UNSOLVED_CUSTOM_FIELD] = coerce_boolean_value(value)
  end

  private

  def coerce_boolean_value(value)
    return "false" if value.blank?
    %w[true false].include?(value.to_s) ? value.to_s : "false"
  end

  def reset_accepted_cache
    DiscourseSolved::AcceptedAnswerCache.reset_accepted_answer_cache
  end
end
