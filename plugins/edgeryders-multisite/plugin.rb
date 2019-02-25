# name: EdgerydersMultisite
# about:
# version: 0.1
# authors: damingo
# url: https://github.com/damingo


register_asset "stylesheets/common/edgeryders-multisite.scss"


enabled_site_setting :edgeryders_multisite_enabled

PLUGIN_NAME ||= "EdgerydersMultisite".freeze

after_initialize do
  
  # see lib/plugin/instance.rb for the methods available in this context
  

  module ::EdgerydersMultisite
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace EdgerydersMultisite
    end
  end

  

  
  require_dependency "application_controller"
  class EdgerydersMultisite::ActionsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :ensure_logged_in

    def list
      render json: success_json
    end
  end

  EdgerydersMultisite::Engine.routes.draw do
    get "/list" => "actions#list"
  end

  Discourse::Application.routes.append do
    mount ::EdgerydersMultisite::Engine, at: "/edgeryders-multisite"
  end
  
end
