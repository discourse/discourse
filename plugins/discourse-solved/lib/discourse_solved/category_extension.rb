# frozen_string_literal: true

module DiscourseSolved::CategoryExtension
  extend ActiveSupport::Concern

  prepended { after_save :reset_accepted_cache, if: -> { SiteSetting.solved_enabled? } }

  def solved_auto_close_hours
    hours = custom_fields["solved_topics_auto_close_hours"].to_i
    [hours, DiscourseSolved::MAX_AUTO_CLOSE_HOURS].min
  end

  private

  def reset_accepted_cache
    DiscourseSolved::AcceptedAnswerCache.reset_accepted_answer_cache
  end
end
