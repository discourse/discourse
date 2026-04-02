# frozen_string_literal: true

class Admin::ProblemChecksController < Admin::AdminController
  def index
    trackers = ProblemCheckTracker.all.order(:identifier, :target)
    render_serialized(trackers, ProblemCheckTrackerSerializer)
  end
end
