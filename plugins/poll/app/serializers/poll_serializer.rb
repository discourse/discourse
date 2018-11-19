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
             :close

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

end
