# frozen_string_literal: true

class Admin::RobotsTxtController < Admin::AdminController

  def show
    render json: { robots_txt: current_robots_txt, overridden: @overridden }
  end

  def update
    params.require(:robots_txt)
    SiteSetting.overridden_robots_txt = params[:robots_txt]

    render json: { robots_txt: current_robots_txt, overridden: @overridden }
  end

  def reset
    SiteSetting.overridden_robots_txt = ""
    render json: { robots_txt: original_robots_txt, overridden: false }
  end

  private

  def current_robots_txt
    robots_txt = SiteSetting.overridden_robots_txt.presence
    @overridden = robots_txt.present?
    robots_txt ||= original_robots_txt
    robots_txt
  end

  def original_robots_txt
    if SiteSetting.allow_index_in_robots_txt?
      @robots_info = ::RobotsTxtController.fetch_default_robots_info
      render_to_string "robots_txt/index"
    else
      render_to_string "robots_txt/no_index"
    end
  end
end
