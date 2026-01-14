# frozen_string_literal: true

module DiscourseSolved::CategoryExtension
  extend ActiveSupport::Concern

  prepended { after_save :reset_accepted_cache, if: -> { SiteSetting.solved_enabled? } }

  private

  def reset_accepted_cache
    DiscourseSolved::AcceptedAnswerCache.reset_accepted_answer_cache
  end
end
