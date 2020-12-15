# frozen_string_literal: true

class DoNotDisturbController < ApplicationController
  requires_login

  def create
    raise Discourse::InvalidParameters.new(:duration) if params[:duration].blank?

    duration_minutes = (Integer(params[:duration]) rescue false)

    ends_at = duration_minutes ?
      ends_at_from_minutes(duration_minutes) :
      ends_at_from_string(params[:duration])

    new_timing = current_user.do_not_disturb_timings.new(starts_at: Time.current, ends_at: ends_at)

    if new_timing.save
      current_user.publish_do_not_disturb(ends_at: ends_at)
      render json: { ends_at: ends_at }
    else
      render json: { errors: new_timing.errors.full_messages }, status: 400
    end
  end

  def destroy
    current_user.active_do_not_disturb_timings.destroy_all
    render json: success_json
  end

  private

  def ends_at_from_minutes(duration)
    Time.current + duration.minutes
  end

  def ends_at_from_string(string)
    if string == 'tomorrow'
      Time.now.end_of_day.utc
    else
      raise Discourse::InvalidParameters.new(:duration)
    end
  end
end
