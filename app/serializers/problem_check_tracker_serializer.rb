# frozen_string_literal: true

class ProblemCheckTrackerSerializer < ApplicationSerializer
  attributes :id, :identifier, :target, :last_run_at, :ignored_at, :status

  def status
    object.passing? ? "passing" : "failing"
  end
end
