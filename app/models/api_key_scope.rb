# frozen_string_literal: true

class ApiKeyScope < ActiveRecord::Base
  validates_presence_of :resource
  validates_presence_of :action

  class << self
    def list_actions
      actions = %w[list#category_feed]

      %i[latest unread new top].each { |f| actions.concat(["list#category_#{f}", "list##{f}"]) }

      actions
    end

    def default_mappings
      return @default_mappings unless @default_mappings.nil?

      mappings = {
        global: {
          read: { methods: %i[get] }
        },
        topics: {
          write: { actions: %w[posts#create], params: %i[topic_id] },
          read: {
            actions: %w[topics#show topics#feed topics#posts],
            params: %i[topic_id], aliases: { topic_id: :id }
          },
          read_lists: {
            actions: list_actions, params: %i[category_id],
            aliases: { category_id: :category_slug_path_with_id }
          },
          wordpress: { actions: %w[topics#wordpress], params: %i[topic_id] }
        },
        posts: {
          edit: { actions: %w[posts#update], params: %i[id] }
        },
        uploads: {
          create: {
            actions: %w[
              uploads#create
              uploads#generate_presigned_put
              uploads#complete_external_upload
              uploads#create_multipart
              uploads#batch_presign_multipart_parts
              uploads#abort_multipart
              uploads#complete_multipart
            ]
          }
        },
        users: {
          bookmarks: { actions: %w[users#bookmarks], params: %i[username] },
          sync_sso: { actions: %w[admin/users#sync_sso], params: %i[sso sig] },
          show: { actions: %w[users#show], params: %i[username external_id external_provider] },
          check_emails: { actions: %w[users#check_emails], params: %i[username] },
          update: { actions: %w[users#update], params: %i[username] },
          log_out: { actions: %w[admin/users#log_out] },
          anonymize: { actions: %w[admin/users#anonymize] },
          delete: { actions: %w[admin/users#destroy] },
          list: { actions: %w[admin/users#index] },
        },
        email: {
          receive_emails: { actions: %w[admin/email#handle_mail] }
        },
        badges: {
          create: { actions: %w[admin/badges#create] },
          show: { actions: %w[badges#show] },
          update: { actions: %w[admin/badges#update] },
          delete: { actions: %w[admin/badges#destroy] },
          list_user_badges: { actions: %w[user_badges#username], params: %i[username] },
          assign_badge_to_user: { actions: %w[user_badges#create], params: %i[username] },
          revoke_badge_from_user: { actions: %w[user_badges#destroy] },
        }
      }

      parse_resources!(mappings)
      @default_mappings = mappings
    end

    def scope_mappings
      plugin_mappings = DiscoursePluginRegistry.api_key_scope_mappings
      return default_mappings if plugin_mappings.empty?

      default_mappings.deep_dup.tap do |mappings|
        plugin_mappings.each do |plugin_mapping|
          parse_resources!(plugin_mapping)
          mappings.deep_merge!(plugin_mapping)
        end
      end
    end

    def parse_resources!(mappings)
      mappings.each_value do |resource_actions|
        resource_actions.each_value do |action_data|
          action_data[:urls] = find_urls(actions: action_data[:actions], methods: action_data[:methods])
        end
      end
    end

    def find_urls(actions:, methods:)
      urls = []

      if actions.present?
        routes = Rails.application.routes.routes.to_a
        Rails::Engine.descendants.each do |engine|
          next if engine == Rails::Application # abstract engine, can't call routes on it
          next if engine == Discourse::Application # equiv. to Rails.application
          routes.concat(engine.routes.routes.to_a)
        end

        routes.each do |route|
          defaults = route.defaults
          action = "#{defaults[:controller].to_s}##{defaults[:action]}"
          path = route.path.spec.to_s.gsub(/\(\.:format\)/, '')
          api_supported_path = path.end_with?('.rss') || route.path.requirements[:format]&.match?('json')
          excluded_paths = %w[/new-topic /new-message /exception]

          if actions.include?(action) && api_supported_path && !excluded_paths.include?(path)
            urls << "#{path} (#{route.verb})"
          end
        end
      end

      if methods.present?
        methods.each do |method|
          urls << "* (#{method})"
        end
      end

      urls
    end
  end

  def permits?(env)
    RouteMatcher.new(**mapping.except(:urls), allowed_param_values: allowed_parameters).match?(env: env)
  end

  private

  def mapping
    @mapping ||= self.class.scope_mappings.dig(resource.to_sym, action.to_sym)
  end
end

# == Schema Information
#
# Table name: api_key_scopes
#
#  id                 :bigint           not null, primary key
#  api_key_id         :integer          not null
#  resource           :string           not null
#  action             :string           not null
#  allowed_parameters :json
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_api_key_scopes_on_api_key_id  (api_key_id)
#
