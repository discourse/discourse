class RobotsTxtController < ApplicationController
  layout false
  skip_before_action :preload_json, :check_xhr, :redirect_to_login_if_required

  def index
    if SiteSetting.allow_index_in_robots_txt
      path = :index
      @crawler_delayed_agents = []

      SiteSetting.slow_down_crawler_user_agents.split('|').each do |agent|
        @crawler_delayed_agents << [agent, SiteSetting.slow_down_crawler_rate]
      end

      if SiteSetting.whitelisted_crawler_user_agents.present?
        @allowed_user_agents = SiteSetting.whitelisted_crawler_user_agents.split('|')
        @disallowed_user_agents = ['*']
      elsif SiteSetting.blacklisted_crawler_user_agents.present?
        @allowed_user_agents = ['*']
        @disallowed_user_agents = SiteSetting.blacklisted_crawler_user_agents.split('|')
      else
        @allowed_user_agents = ['*']
      end
    else
      path = :no_index
    end

    render path, content_type: 'text/plain'
  end
end
