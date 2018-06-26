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
    /my/
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
    if SiteSetting.allow_index_in_robots_txt?
      @robots_info = fetch_robots_info
      render :index, content_type: 'text/plain'
    else
      render :no_index, content_type: 'text/plain'
    end
  end

  # If you are hosting Discourse in a subfolder, you will need to create your robots.txt
  # in the root of your web server with the appropriate paths. This method will return
  # JSON that can be used by a script to create a robots.txt that works well with your
  # existing site.
  def builder
    render json: fetch_robots_info
  end

protected

  def fetch_robots_info
    deny_paths = DISALLOWED_PATHS.map { |p| Discourse.base_uri + p }
    deny_all = [ "#{Discourse.base_uri}/" ]

    result = {
      header: "# See http://www.robotstxt.org/robotstxt.html for documentation on how to use the robots.txt file",
      agents: []
    }

    if SiteSetting.whitelisted_crawler_user_agents.present?
      SiteSetting.whitelisted_crawler_user_agents.split('|').each do |agent|
        result[:agents] << { name: agent, disallow: deny_paths }
      end

      result[:agents] << { name: '*', disallow: deny_all }
    elsif SiteSetting.blacklisted_crawler_user_agents.present?
      result[:agents] << { name: '*', disallow: deny_paths }
      SiteSetting.blacklisted_crawler_user_agents.split('|').each do |agent|
        result[:agents] << { name: agent, disallow: deny_all }
      end
    else
      result[:agents] << { name: '*', disallow: deny_paths }
    end

    if SiteSetting.slow_down_crawler_user_agents.present?
      SiteSetting.slow_down_crawler_user_agents.split('|').each do |agent|
        result[:agents] << {
          name: agent,
          delay: SiteSetting.slow_down_crawler_rate,
          disallow: deny_paths
        }
      end
    end

    result
  end

end
