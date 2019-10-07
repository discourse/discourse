# frozen_string_literal: true

# name: discourse-automation
# about:
# version: 0.1
# authors: jjaffeux
# url: https://github.com/jjaffeux/discourse-automation

register_asset 'stylesheets/common/discourse-automation.scss'
enabled_site_setting :discourse_automation_enabled
add_admin_route 'discourse_automation.title', 'discourse-automation.workflows.index'

PLUGIN_NAME ||= 'discourse-automation'

after_initialize do
  [
    '../app/controllers/admin/workflows_controller',
    '../app/controllers/admin/plans_controller',
    '../app/controllers/admin/triggers_controller',
    '../app/controllers/admin/plannables_controller',
    '../app/controllers/admin/workflowables_controller',
    '../app/controllers/admin/triggerables_controller',
    '../app/serializers/discourse_automation/trigger_serializer',
    '../app/serializers/discourse_automation/workflow_serializer',
    '../app/serializers/discourse_automation/plan_serializer',
    '../app/models/discourse_automation/trigger',
    '../app/models/discourse_automation/plan',
    '../app/models/discourse_automation/workflow',
    '../app/lib/discourse_automation/plannable',
    '../app/lib/discourse_automation/triggerable',
    '../app/lib/discourse_automation/workflowable',
    '../app/jobs/scheduled/recurring_mixin',
    '../app/jobs/scheduled/discourse_automation_every_hour_trigger',
    '../app/jobs/scheduled/discourse_automation_every_ten_minutes_trigger',
    '../app/jobs/scheduled/discourse_automation_every_month_trigger',
    '../app/jobs/scheduled/discourse_automation_every_week_trigger',
    '../app/jobs/scheduled/discourse_automation_every_year_trigger',
    '../app/jobs/scheduled/discourse_automation_every_day_trigger',
    '../app/jobs/regular/discourse_automation_process_plan',
    '../app/jobs/regular/discourse_automation_process_workflow',
    '../app/core_ext/plugin_instance'
  ].each { |path| require File.expand_path(path, __FILE__) }

  on(:user_created) do |user|
    enqueue_workflows(:user_created, target_username: user.username)
  end

  on(:user_added_to_group) do |user, group, options|
    enqueue_workflows(
      :on_group_joined,
      user_id: user.id,
      group_id: group.id,
      options: options
    )
  end

  module ::DiscourseAutomation
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseAutomation
    end

    def self.reset!
      DiscourseAutomation::Triggerable.reset!
      DiscourseAutomation::Plannable.reset!
    end
  end

  DiscourseAutomation::Engine.routes.draw do
    get '/admin/plugins/discourse-automation/workflows' => 'workflows#index'
    get '/admin/plugins/discourse-automation/workflows/:id' => 'workflows#show'
    put '/admin/plugins/discourse-automation/workflows/:id' => 'workflows#update'
    delete '/admin/plugins/discourse-automation/workflows/:id' => 'workflows#destroy'
    post '/admin/plugins/discourse-automation/workflows' => 'workflows#create'

    post '/admin/plugins/discourse-automation/plans' => 'plans#create'
    put '/admin/plugins/discourse-automation/plans/:id' => 'plans#update'
    delete '/admin/plugins/discourse-automation/plans/:id' => 'plans#destroy'

    post '/admin/plugins/discourse-automation/triggers' => 'triggers#create'
    put '/admin/plugins/discourse-automation/triggers/:id' => 'triggers#update'
    delete '/admin/plugins/discourse-automation/triggers/:id' => 'triggers#destroy'

    get '/admin/plugins/discourse-automation/plannables' => 'plannables#index'

    get '/admin/plugins/discourse-automation/triggerables' => 'triggerables#index'

    get '/admin/plugins/discourse-automation/workflowables' => 'workflowables#index'

    get '/admin/plugins/discourse-automation', to: redirect('/admin/plugins/discourse-automation/workflows')
  end

  Discourse::Application.routes.append do
    mount ::DiscourseAutomation::Engine, at: '/'
  end

  if !Rails.env.test?
    add_automation_trigger :on_user_created do
      provides :created_username, :username
    end

    add_automation_trigger :on_group_joined do
      field :joined_group, type: :group

      provides :joined_group_name, :group_name
      provides :joining_username, :username

      trigger? do |args, options|
        should_trigger = false

        user = User.find(args['user_id'])
        groups = Group.where(id: args['group_id'])

        if groups && user
          should_trigger = Group.member_of(groups, user).exists?
        end

        should_trigger
      end
    end

    add_automation_trigger :every_hour
    add_automation_trigger :every_ten_minutes
    add_automation_trigger :every_day

    add_automation_plan :send_personal_message do
      field :title, type: :string, required: true
      field :raw, type: :post, required: true
      field :target_username, type: :user, required: true, providable_type: 'user'
      field :creator_username, type: :user, required: true, default: 'system'

      plan! do |options, trigger_args|
        if trigger_args[:user_id]
          target_username = User.find(trigger_args[:user_id]).username
        else
          target_username = options['target_username']['value']
        end

        creator = User.find_by(username: options['creator_username']['value'])

        placeholders = {
          target_username: target_username
        }

        post_args = {
          title: replace(options['title']['value'], placeholders),
          raw: replace(options['raw']['value'], placeholders),
          target_usernames: [target_username],
          category: nil,
          archetype: Archetype.private_message
        }

        PostCreator.new(creator, post_args).create!
      end
    end

    add_automation_plan :publish_random_topic do

      field :from_category_id, type: :category, required: true
      field :to_category_id, type: :category, required: true

      plan! do |options, trigger_args|
        from_category = Category.find(options['from_category_id']['value'])
        topic = from_category.topics.where(closed: false, archived: false).sample
        TopicPublisher.new(topic, Discourse.system_user, options['to_category_id']['value'])
                      .publish!
      end
    end

    # add_automation_plan :webhook do
    #
    #   field :endpoint, type: :string, required: true
    #   field :verb, type: :string, required: true, default: 'GET'
    #
    #   plan! do |args|
    #     headers = request_headers.merge(
    #       'Accept-Encoding' => 'application/json',
    #       'Host' => Discourse.base_url
    #     )
    #     req = Net::HTTP::Get.new(args['endpoint'], headers)
    #     http.request(req)
    #   end
    # end

    add_automation_plan :send_custom_notification do
      field :title, type: :string, required: true
      field :message, type: :string, required: true
      field :icon, type: :string, required: true
      field :url, type: :string, required: true
      field :target_username, type: :user, required: true, providable_type: 'user'

      plan! do |options, trigger_args|
        if trigger_args[:user_id]
          target = User.find(trigger_args[:user_id])
        else
          target = User.find_by(username: options['target_username']['value'])
        end

        Notification.create!(
          notification_type: Notification.types[:custom],
          user_id: target.id,
          data: {
            customMessage: options['message']['value'],
            customTranslatedTitle: options['title']['value'],
            customIcon: options['icon']['value'],
            customUrl: options['url']['value']
          }.to_json
        )
      end
    end

    on(:cake_day) do |user|
      enqueue_workflows(:cake_day, user_id: user.id)
    end

    add_automation_workflowable(:empty_workflow)

    add_automation_workflowable(:secret_santa) do
      trigger(:on_group_joined, {
        joined_group: 'staff'
      })

      plan(:send_personal_message, {
        title: "It's santa time!",
        raw: "This is your time to be santa!",
        target_username: 'system'
      })
    end

    add_automation_workflowable(:on_boarding) do
      trigger(:on_user_created)

      plan(:send_personal_message, {
        options: {
          title: { value: 'This is your first day!' },
          target_username: { use_provided: true },
          creator_username: { value: 'system' }
        },
        delay: 0
      })

      plan(:send_personal_message, {
        options: {
          target_username: { use_provided: true },
          creator_username: { value: 'system' },
        },
        delay: 180
      })
    end
  end
end
