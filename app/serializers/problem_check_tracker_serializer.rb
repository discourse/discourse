# frozen_string_literal: true

class ProblemCheckTrackerSerializer < ApplicationSerializer
  attributes :id, :identifier, :target, :last_run_at, :ignored, :status

  def status
    object.passing? ? "passing" : "failing"
  end

  def ignored
    object.ignored?
  end
end
