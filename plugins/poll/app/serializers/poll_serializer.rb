# frozen_string_literal: true

class PollSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :type,
             :status,
             :public,
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
             :title

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
    object.poll_votes.count("DISTINCT user_id") + object.anonymous_voters.to_i
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
end
