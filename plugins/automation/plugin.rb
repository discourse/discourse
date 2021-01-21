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
    '../app/controllers/discourse_automation/admin_discourse_automation_scriptables_controller',
    '../app/controllers/discourse_automation/admin_discourse_automation_triggerables_controller',
    '../app/serializers/discourse_automation/automation_serializer',
    '../app/serializers/discourse_automation/automation_field_serializer',
    '../app/serializers/discourse_automation/trigger_serializer',
    '../app/lib/discourse_automation/triggerable',
    '../app/lib/discourse_automation/scriptable',
    '../app/models/discourse_automation/automation',
    '../app/models/discourse_automation/pending_automation',
    '../app/models/discourse_automation/pending_pm',
    '../app/models/discourse_automation/field',
    '../app/models/discourse_automation/trigger',
    '../app/jobs/scheduled/discourse_automation_tracker',
    '../app/core_ext/plugin_instance',
    '../app/lib/discourse_automation/triggers/user_added_to_group',
    '../app/lib/discourse_automation/triggers/point_in_time',
    '../app/lib/discourse_automation/scripts/gift_exchange',
    '../app/lib/discourse_automation/scripts/send_pms'
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
        get '/scriptables' => 'admin_discourse_automation_scriptables#index'
        get '/triggerables' => 'admin_discourse_automation_triggerables#index'

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

  on(:user_added_to_group) do |user, group|
    name = DiscourseAutomation::Triggerable::USER_ADDED_TO_GROUP

    DiscourseAutomation::Trigger.where(name: name).find_each do |trigger|
      if trigger.metadata['group_ids'].include?(group.id)
        trigger.run!(
          'kind' => DiscourseAutomation::Triggerable::USER_ADDED_TO_GROUP,
          'user' => user,
          'group' => group
        )
      end
    end
  end
end

Rake::Task.define_task run_automation: :environment do
  script_methods = DiscourseAutomation::Scriptable.all

  scripts = []

  DiscourseAutomation::Automation.find_each do |automation|
    script_methods.each do |name|
      type = name.to_s.gsub('script_', '')

      next if type != automation.script

      script = DiscourseAutomation::Scriptable.new(automation)
      script.public_send(name)
      scripts << script.script.call
    end
  end
end
