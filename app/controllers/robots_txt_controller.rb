class RobotsTxtController < ApplicationController
  layout false
  skip_before_action :preload_json, :check_xhr, :redirect_to_login_if_required

  # NOTE: order is important!
  DISALLOWED_PATHS ||= %w{
    /auth/cas
    /auth/facebook/callback
    /auth/twitter/callback
    /auth/google/callback
    /auth/yahoo/callback
    /auth/github/callback
    /auth/cas/callback
    /assets/browser-update*.js
    /users/
    /u/
    /badges/
    /search
    /search/
    /tags
    /tags/
    /email/
    /session
    /session/
    /admin
    /admin/
    /user-api-key
    /user-api-key/
    /*?api_key*
    /*?*api_key*
    /groups
    /groups/
    /t/*/*.rss
    /tags/*.rss
    /c/*.rss
  }

  def index
    if SiteSetting.allow_index_in_robots_txt
      path = :index

      @crawler_delayed_agents = SiteSetting.slow_down_crawler_user_agents.split('|').map { |agent|
        [agent, SiteSetting.slow_down_crawler_rate]
      }

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
