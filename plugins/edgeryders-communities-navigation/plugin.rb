# name: EdgerydersCommunitiesNavigation
# about:
# version: 0.1
# authors: damingo
# url: https://github.com/damingo


register_asset "stylesheets/common/edgeryders-communities-navigation.scss"

register_svg_icon "comments-o" if respond_to?(:register_svg_icon)

enabled_site_setting :edgeryders_communities_navigation_enabled

PLUGIN_NAME ||= "EdgerydersCommunitiesNavigation".freeze

after_initialize do
  
  # see lib/plugin/instance.rb for the methods available in this context
  

  module ::EdgerydersCommunitiesNavigation
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace EdgerydersCommunitiesNavigation
    end
  end

  

  
  require_dependency "application_controller"
  class EdgerydersCommunitiesNavigation::ActionsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :ensure_logged_in

    def list
      render json: success_json
    end
  end

  EdgerydersCommunitiesNavigation::Engine.routes.draw do
    get "/list" => "actions#list"
  end

  Discourse::Application.routes.append do
    mount ::EdgerydersCommunitiesNavigation::Engine, at: "/edgeryders-communities-navigation"
  end
  
end
