# frozen_string_literal: true

class DoNotDisturbController < ApplicationController
  requires_login

  def create
    raise Discourse::InvalidParameters.new(:duration) if params[:duration].blank?

    duration_minutes =
      (
        begin
          Integer(params[:duration])
        rescue StandardError
          false
        end
      )

    ends_at =
      (
        if duration_minutes
          ends_at_from_minutes(duration_minutes)
        else
          ends_at_from_string(params[:duration])
        end
      )

    new_timing = UserNotificationPause.new(user: current_user).start(ends_at:)

    if new_timing.persisted?
      render json: { ends_at: ends_at }
    else
      render_json_error(new_timing)
    end
  end

  def destroy
    UserNotificationPause.new(user: current_user).end_all
    render json: success_json
  end

  private

  def ends_at_from_minutes(duration)
    duration.minutes.from_now
  end

  def ends_at_from_string(string)
    if string == "tomorrow"
      Time.now.end_of_day.utc
    else
      raise Discourse::InvalidParameters.new(:duration)
    end
  end
end
