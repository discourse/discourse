# frozen_string_literal: true

class RobotsTxtController < ApplicationController
  layout false
  skip_before_action :preload_json,
                     :check_xhr,
                     :redirect_to_login_if_required,
                     :redirect_to_profile_if_required

  OVERRIDDEN_HEADER = "# This robots.txt file has been customized at /admin/customize/robots\n"

  # NOTE: order is important!
  DISALLOWED_PATHS = %w[
    /admin/
    /auth/
    /assets/browser-update*.js
    /email/
    /session
    /user-api-key
    /*?api_key*
    /*?*api_key*
  ].freeze

  DISALLOWED_WITH_HEADER_PATHS = %w[/badges /u/ /my /search /tag/*/l /g /t/*/*.rss /c/*.rss].freeze

  def index
    if (overridden = SiteSetting.overridden_robots_txt.dup).present?
      overridden.prepend(OVERRIDDEN_HEADER) if guardian.is_admin? && !is_api?
      render plain: overridden
      return
    end
    if SiteSetting.allow_index_in_robots_txt?
      @robots_info = self.class.fetch_default_robots_info
      render :index, content_type: "text/plain"
    else
      render :no_index, content_type: "text/plain"
    end
  end

  # If you are hosting Discourse in a subfolder, you will need to create your robots.txt
  # in the root of your web server with the appropriate paths. This method will return
  # JSON that can be used by a script to create a robots.txt that works well with your
  # existing site.
  def builder
    result = self.class.fetch_default_robots_info
    overridden = SiteSetting.overridden_robots_txt
    result[:overridden] = overridden if overridden.present?
    render json: result
  end

  def self.fetch_default_robots_info
    deny_paths_googlebot = DISALLOWED_PATHS.map { |p| Discourse.base_path + p }
    deny_paths =
      deny_paths_googlebot + DISALLOWED_WITH_HEADER_PATHS.map { |p| Discourse.base_path + p }
    deny_all = ["#{Discourse.base_path}/"]

    result = {
      header:
        "# See http://www.robotstxt.org/robotstxt.html for documentation on how to use the robots.txt file",
      agents: [],
    }

    if SiteSetting.allowed_crawler_user_agents.present?
      SiteSetting
        .allowed_crawler_user_agents
        .split("|")
        .each do |agent|
          paths = agent == "Googlebot" ? deny_paths_googlebot : deny_paths
          result[:agents] << { name: agent, disallow: paths }
        end

      result[:agents] << { name: "*", disallow: deny_all }
    else
      if SiteSetting.blocked_crawler_user_agents.present?
        SiteSetting
          .blocked_crawler_user_agents
          .split("|")
          .each { |agent| result[:agents] << { name: agent, disallow: deny_all } }
      end

      result[:agents] << { name: "*", disallow: deny_paths }

      result[:agents] << { name: "Googlebot", disallow: deny_paths_googlebot }
    end

    DiscourseEvent.trigger(:robots_info, result)

    result
  end
end
