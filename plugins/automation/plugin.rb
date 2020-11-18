# frozen_string_literal: true

# name: discourse-automation
# about:
# version: 0.1
# authors: jjaffeux
# url: https://github.com/jjaffeux/discourse-automation

register_asset 'stylesheets/common/discourse-automation.scss'
enabled_site_setting :discourse_automation_enabled

PLUGIN_NAME ||= 'discourse-automation'

after_initialize do
  [
    '../app/controllers/discourse_automation/admin_discourse_automation_controller',
    '../app/controllers/discourse_automation/admin_discourse_automation_automations_controller',
    '../app/controllers/discourse_automation/admin_discourse_automation_scripts_controller',
    '../app/controllers/discourse_automation/admin_discourse_automation_triggers_controller',
    '../app/serializers/discourse_automation/automation_serializer',
    '../app/serializers/discourse_automation/automation_field_serializer',
    '../app/serializers/discourse_automation/trigger_serializer',
    '../app/lib/discourse_automation/script_dsl',
    '../app/lib/discourse_automation/script',
    '../app/models/discourse_automation/automation',
    '../app/models/discourse_automation/pending_automation',
    '../app/models/discourse_automation/field',
    '../app/models/discourse_automation/trigger',
    '../app/jobs/scheduled/discourse_automation_tracker',
    '../app/core_ext/plugin_instance',
    '../app/scripts/gift_exchange',
  ].each { |path| require File.expand_path(path, __FILE__) }

  module ::DiscourseAutomation
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseAutomation
    end
  end

  add_admin_route 'discourse_automation.title', 'discourse-automation'

  DiscourseAutomation::Engine.routes.draw do
    scope '/admin/plugins/discourse-automation', as: 'admin_discourse_automation', constraints: StaffConstraint.new do
      scope format: false do
        get '/' => 'admin_discourse_automation#index'
        get '/new' => 'admin_discourse_automation#new'
        get '/:id' => 'admin_discourse_automation#edit'
      end

      scope format: :json do
        get '/scripts' => 'admin_discourse_automation_scripts#index'
        get '/triggers' => 'admin_discourse_automation_triggers#index'

        get '/automations' => 'admin_discourse_automation_automations#index'
        get '/automations/:id' => 'admin_discourse_automation_automations#show'
        put '/automations/:id' => 'admin_discourse_automation_automations#update'
        post '/automations' => 'admin_discourse_automation_automations#create'
      end
    end
  end

  Discourse::Application.routes.append do
    mount ::DiscourseAutomation::Engine, at: '/'
  end
end

Rake::Task.define_task run_automation: :environment do
  script_methods = DiscourseAutomation::Script.all

  scripts = []

  DiscourseAutomation::Automation.find_each do |automation|
    script_methods.each do |name|
      type = name.to_s.gsub('script_', '')

      next if type != automation.script

      script = DiscourseAutomation::Script.new(automation)
      script.public_send(name)
      scripts << script.script_block.call
    end
  end
end
