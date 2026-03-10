# frozen_string_literal: true

module DiscourseSolved::CategoryExtension
  extend ActiveSupport::Concern

  prepended { after_save :reset_accepted_cache, if: -> { SiteSetting.solved_enabled? } }

  def solved_auto_close_days
    days = custom_fields["solved_topics_auto_close_days"].to_i
    if days.zero?
      hours = custom_fields["solved_topics_auto_close_hours"].to_i
      days = [1, (hours / 24.0).round].max if hours > 0
    end
    [days, DiscourseSolved::MAX_AUTO_CLOSE_DAYS].min
  end

  private

  def reset_accepted_cache
    DiscourseSolved::AcceptedAnswerCache.reset_accepted_answer_cache
  end
end
