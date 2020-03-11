# frozen_string_literal: true

class PollSerializer < ApplicationSerializer
  attributes :name,
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
             :groups

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
    object.poll_options.map { |o| PollOptionSerializer.new(o, root: false).as_json }
  end

  def voters
    object.poll_votes.map { |v| v.user_id }.uniq.count + object.anonymous_voters.to_i
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
    object.can_see_voters?(scope)
  end

end
