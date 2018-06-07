# name: discourse-narrative-bot
# about: Introduces staff to Discourse
# version: 1.0
# authors: Nick Sahler, Alan Tan
# url: https://github.com/discourse/discourse/tree/master/plugins/discourse-narrative-bot

enabled_site_setting :discourse_narrative_bot_enabled
hide_plugin if self.respond_to?(:hide_plugin)

if Rails.env == "development"
  # workaround, teach reloader to reload jobs
  # if we do not do this then
  #
  # 1. on reload rails goes and undefines Jobs::Base
  # 2. as a side effect this undefines Jobs::BotInput
  # 3. we have a post_edited hook that queues a job for bot input
  # 4. if you are not running sidekiq in dev every time you save a post it will trigger it
  # 5. but the constant can not be autoloaded
  Rails.configuration.autoload_paths << File.expand_path('../autoload', __FILE__)
end

require_relative 'lib/discourse_narrative_bot/welcome_post_type_site_setting.rb'

after_initialize do
  SeedFu.fixture_paths << Rails.root.join("plugins", "discourse-narrative-bot", "db", "fixtures").to_s

  Mime::Type.register "image/svg+xml", :svg

  [
    '../autoload/jobs/bot_input.rb',
    '../autoload/jobs/narrative_timeout.rb',
    '../autoload/jobs/narrative_init.rb',
    '../autoload/jobs/send_default_welcome_message.rb',
    '../autoload/jobs/onceoff/grant_badges.rb',
    '../autoload/jobs/onceoff/remap_old_bot_images.rb',
    '../lib/discourse_narrative_bot/actions.rb',
    '../lib/discourse_narrative_bot/base.rb',
    '../lib/discourse_narrative_bot/new_user_narrative.rb',
    '../lib/discourse_narrative_bot/advanced_user_narrative.rb',
    '../lib/discourse_narrative_bot/track_selector.rb',
    '../lib/discourse_narrative_bot/certificate_generator.rb',
    '../lib/discourse_narrative_bot/dice.rb',
    '../lib/discourse_narrative_bot/quote_generator.rb',
    '../lib/discourse_narrative_bot/magic_8_ball.rb',
    '../lib/discourse_narrative_bot/welcome_post_type_site_setting.rb'
  ].each { |path| load File.expand_path(path, __FILE__) }

  # Disable welcome message because that is what the bot is supposed to replace.
  SiteSetting.send_welcome_message = false if SiteSetting.send_welcome_message

  require_dependency 'plugin_store'

  module ::DiscourseNarrativeBot
    PLUGIN_NAME = "discourse-narrative-bot".freeze

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseNarrativeBot
    end

    class Store
      def self.set(key, value)
        ::PluginStore.set(PLUGIN_NAME, key, value)
      end

      def self.get(key)
        ::PluginStore.get(PLUGIN_NAME, key)
      end

      def self.remove(key)
        ::PluginStore.remove(PLUGIN_NAME, key)
      end
    end

    class CertificatesController < ::ApplicationController
      layout :false
      skip_before_action :check_xhr

      def generate
        raise Discourse::InvalidParameters.new('user_id must be present') unless params[:user_id]&.present?

        user = User.find_by(id: params[:user_id])
        raise Discourse::NotFound if user.blank?

        raise Discourse::InvalidParameters.new('date must be present') unless params[:date]&.present?

        generator = CertificateGenerator.new(user, params[:date])

        svg =
          case params[:type]
          when 'advanced'
            generator.advanced_user_track
          else
            generator.new_user_track
          end

        respond_to do |format|
          format.svg { render inline: svg }
        end
      end
    end
  end

  DiscourseNarrativeBot::Engine.routes.draw do
    get "/certificate" => "certificates#generate", format: :svg
  end

  Discourse::Application.routes.append do
    mount ::DiscourseNarrativeBot::Engine, at: "/discobot"
  end

  self.add_model_callback(User, :after_destroy) do
    DiscourseNarrativeBot::Store.remove(self.id)
  end

  self.add_model_callback(User, :after_commit, on: :create) do
    if SiteSetting.discourse_narrative_bot_welcome_post_delay == 0
      self.enqueue_bot_welcome_post
    end
  end

  self.on(:user_first_logged_in) do |user|
    if SiteSetting.discourse_narrative_bot_welcome_post_delay > 0
      user.enqueue_bot_welcome_post
    end
  end

  self.on(:user_unstaged) do |user|
    user.enqueue_bot_welcome_post
  end

  self.add_to_class(:user, :enqueue_bot_welcome_post) do
    return if SiteSetting.disable_discourse_narrative_bot_welcome_post

    delay = SiteSetting.discourse_narrative_bot_welcome_post_delay

    case SiteSetting.discourse_narrative_bot_welcome_post_type
    when 'new_user_track'
      if enqueue_narrative_bot_job?
        Jobs.enqueue_in(delay, :narrative_init,
          user_id: self.id,
          klass: DiscourseNarrativeBot::NewUserNarrative.to_s
        )
      end
    when 'welcome_message'
      Jobs.enqueue_in(delay, :send_default_welcome_message, user_id: self.id)
    end
  end

  self.add_to_class(:user, :enqueue_narrative_bot_job?) do
    SiteSetting.discourse_narrative_bot_enabled &&
      self.id > 0 &&
      !self.anonymous? &&
      !self.staged &&
      !SiteSetting.discourse_narrative_bot_ignored_usernames.split('|'.freeze).include?(self.username)
  end

  self.on(:post_created) do |post, options|
    user = post.user

    if user.enqueue_narrative_bot_job? && !options[:skip_bot]
      Jobs.enqueue(:bot_input,
        user_id: user.id,
        post_id: post.id,
        input: :reply
      )
    end
  end

  self.on(:post_edited) do |post|
    if post.user.enqueue_narrative_bot_job?
      Jobs.enqueue(:bot_input,
        user_id: post.user.id,
        post_id: post.id,
        input: :edit
      )
    end
  end

  self.on(:post_destroyed) do |post, options, user|
    if user.enqueue_narrative_bot_job? && !options[:skip_bot]
      Jobs.enqueue(:bot_input,
        user_id: user.id,
        post_id: post.id,
        topic_id: post.topic_id,
        input: :delete
      )
    end
  end

  self.on(:post_recovered) do |post, _, user|
    if user.enqueue_narrative_bot_job?
      Jobs.enqueue(:bot_input,
        user_id: user.id,
        post_id: post.id,
        input: :recover
      )
    end
  end

  self.add_model_callback(PostAction, :after_commit, on: :create) do
    if self.user.enqueue_narrative_bot_job?
      input =
        case self.post_action_type_id
        when *PostActionType.flag_types_without_custom.values
          :flag
        when PostActionType.types[:like]
          :like
        when PostActionType.types[:bookmark]
          :bookmark
        end

      if input
        Jobs.enqueue(:bot_input,
          user_id: self.user.id,
          post_id: self.post.id,
          input: input
        )
      end
    end
  end

  self.on(:topic_notification_level_changed) do |_, user_id, topic_id|
    user = User.find_by(id: user_id)

    if user && user.enqueue_narrative_bot_job?
      Jobs.enqueue(:bot_input,
        user_id: user_id,
        topic_id: topic_id,
        input: :topic_notification_level_changed
      )
    end
  end
end
