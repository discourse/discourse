# frozen_string_literal: true

class Admin::RobotsTxtController < Admin::AdminController

  def show
    render json: { content: current_robots_txt, overridden: @overridden }
  end

  def update
    SiteSetting.overridden_robots_txt = params[:content]&.strip

    render json: { content: current_robots_txt, overridden: @overridden }
  end

  private

  def current_robots_txt
    content = SiteSetting.overridden_robots_txt.presence
    @overridden = content.present?
    content ||= original_robots_txt
    content
  end

  def original_robots_txt
    if SiteSetting.allow_index_in_robots_txt?
      @robots_info = ::RobotsTxtController.fetch_robots_info
      render_to_string "robots_txt/index"
    else
      render_to_string "robots_txt/no_index"
    end
  end
end
