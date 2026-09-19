# frozen_string_literal: true

class PollSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :type,
             :status,
             :public,
             :dynamic,
             :results,
             :min,
             :max,
             :step,
             :options,
             :voters,
             :close,
             :preloaded_voters,
             :chart_type,
             :groups,
             :title,
             :ranked_choice_outcome,
             :closed_at,
             :closed_by

  def closed_by
    return if object.closed_by_id.blank? || object.closed_by_id == Discourse::SYSTEM_USER_ID

    BasicUserSerializer.new(object.closed_by, root: false, scope:).as_json
  end

  def public
    true
  end

  def include_public?
    object.everyone?
  end

  def include_min?
    object.min.present? && (object.number? || object.multiple?)
  end

  def include_max?
    object.max.present? && (object.number? || object.multiple?)
  end

  def include_step?
    object.step.present? && object.number?
  end

  def include_groups?
    groups.present?
  end

  def options
    can_see_results = object.can_see_results?(scope.user)

    object.poll_options.map do |option|
      PollOptionSerializer.new(
        option,
        root: false,
        scope: {
          can_see_results: can_see_results,
        },
      ).as_json
    end
  end

  def voters
    object.voters_count + object.anonymous_voters.to_i
  end

  def close
    object.close_at
  end

  def include_close?
    object.close_at.present?
  end

  def preloaded_voters
    DiscoursePoll::Poll.serialized_voters(object)
  end

  def include_preloaded_voters?
    object.can_see_voters?(scope.user)
  end

  def include_ranked_choice_outcome?
    object.ranked_choice? && object.can_see_results?(scope.user)
  end

  def ranked_choice_outcome
    DiscoursePoll::RankedChoice.outcome(object.id)
  end
end
