# frozen_string_literal: true

DiscourseEvent.on(:reviewable_handled) do |event|
  result =
    Reviewable::RecordOutcome.call(
      reviewable: event[:reviewable],
      params: event.slice(:outcome_source, :restriction_type),
    )
  raise ActiveRecord::RecordInvalid.new(result.outcome) unless result.success?
end

DiscourseEvent.on(:reviewable_restriction_applied) do |details|
  result = ReviewableOutcome::AddRestrictions.call(params: details)
  unless result.success?
    raise Discourse::InvalidParameters.new("reviewable outcome could not be updated")
  end
end
