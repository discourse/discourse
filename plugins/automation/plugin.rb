# frozen_string_literal: true

# name: discourse-automation
# about:
# version: 0.1
# authors: jjaffeux
# url: https://github.com/jjaffeux/discourse-automation
gem 'iso8601', '0.13.0'
gem 'json_schemer', '0.2.18'
gem 'rrule', '0.4.2'

register_asset 'stylesheets/common/discourse-automation.scss'
enabled_site_setting :discourse_automation_enabled

PLUGIN_NAME ||= 'discourse-automation'

def handle_post_created_edited(post, action)
  return if post.post_type != Post.types[:regular] || post.user_id < 0

  name = DiscourseAutomation::Triggerable::POST_CREATED_EDITED

  DiscourseAutomation::Automation
    .where(trigger: name)
    .find_each do |automation|
      restricted_category = automation.trigger_field('restricted_category')
      if restricted_category['category_id']
        category_id = post.topic&.category&.parent_category&.id || post.topic&.category&.id
        next if restricted_category['category_id'] != category_id
      end

      automation.trigger!('kind' => name, 'action' => action, 'post' => post)
    end
end

require File.expand_path('../app/lib/discourse_automation/triggerable', __FILE__)
require File.expand_path('../app/lib/discourse_automation/scriptable', __FILE__)
require File.expand_path('../app/core_ext/plugin_instance', __FILE__)

after_initialize do
  [
    '../app/controllers/discourse_automation/admin_discourse_automation_controller',
    '../app/controllers/discourse_automation/admin_discourse_automation_automations_controller',
    '../app/controllers/discourse_automation/admin_discourse_automation_scriptables_controller',
    '../app/controllers/discourse_automation/admin_discourse_automation_triggerables_controller',
    '../app/serializers/discourse_automation/automation_serializer',
    '../app/serializers/discourse_automation/automation_field_serializer',
    '../app/serializers/discourse_automation/trigger_serializer',
    '../app/models/discourse_automation/automation',
    '../app/models/discourse_automation/pending_automation',
    '../app/models/discourse_automation/pending_pm',
    '../app/models/discourse_automation/field',
    '../app/jobs/scheduled/discourse_automation_tracker',
    '../app/jobs/scheduled/stalled_wiki_tracker',
    '../app/lib/discourse_automation/triggers/recurring',
    '../app/lib/discourse_automation/triggers/stalled_wiki',
    '../app/lib/discourse_automation/triggers/user_added_to_group',
    '../app/lib/discourse_automation/triggers/point_in_time',
    '../app/lib/discourse_automation/triggers/post_created_edited',
    '../app/lib/discourse_automation/triggers/topic',
    '../app/lib/discourse_automation/scripts/pin_topic',
    '../app/lib/discourse_automation/scripts/gift_exchange',
    '../app/lib/discourse_automation/scripts/send_pms',
    '../app/lib/discourse_automation/scripts/topic_required_words',
    '../app/lib/discourse_automation/scripts/flag_post_on_words',
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
        delete '/automations/:id' => 'admin_discourse_automation_automations#destroy'
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

    DiscourseAutomation::Automation.where(trigger: name).find_each do |automation|
      joined_group = automation.trigger_field('joined_group')
      if joined_group['group_id'] == group.id
        automation.trigger!(
          'kind' => DiscourseAutomation::Triggerable::USER_ADDED_TO_GROUP,
          'users' => [user],
          'group' => group,
          'placeholders' => {
            'group_name' => group.name
          }
        )
      end
    end
  end

  on(:post_created) do |post|
    handle_post_created_edited(post, :create)
  end

  on(:post_edited) do |post|
    handle_post_created_edited(post, :edit)
  end

  register_topic_custom_field_type('discourse_automation_id', :integer)
  register_post_custom_field_type('stalled_wiki_triggered_at', :string)

  reloadable_patch do
    require 'post'

    class ::Post
      validate :discourse_automation_topic_required_words

      def discourse_automation_topic_required_words
        if topic.custom_fields['discourse_automation_id'].present?
          automation = DiscourseAutomation::Automation.find(topic.custom_fields['discourse_automation_id'])
          if automation&.script == DiscourseAutomation::Scriptable::TOPIC_REQUIRED_WORDS
            words = automation.fields.find_by(name: 'words')

            return if !words

            words = words.metadata['list']

            if words.present?
              if words.none? { |word| raw.include?(word) }
                errors.add(:base, I18n.t('discourse_automation.scriptables.topic_required_words.errors.must_include_word', words: words.join(', ')))
              end
            end
          end
        end
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

      scriptable = automation.scriptable
      scriptable.public_send(name)
      scripts << scriptable.script.call
    end
  end
end
