# frozen_string_literal: true

class Admin::ProblemChecksController < Admin::AdminController
  def index
    trackers = ProblemCheckTracker.all.order(:identifier, :target)
    render_serialized(trackers, ProblemCheckTrackerSerializer)
  end

  def ignore
    tracker = ProblemCheckTracker.find(params[:problem_check_id])

    tracker.ignore!

    render json: success_json
  end

  def watch
    tracker = ProblemCheckTracker.find(params[:problem_check_id])

    tracker.watch!

    render json: success_json
  end
end
