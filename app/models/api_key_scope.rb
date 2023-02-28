# frozen_string_literal: true

class ApiKeyScope < ActiveRecord::Base
  validates_presence_of :resource
  validates_presence_of :action

  class << self
    def list_actions
      actions = %w[list#category_feed list#category_default]

      %i[latest unread new top].each { |f| actions.concat(["list#category_#{f}", "list##{f}"]) }

      actions
    end

    def default_mappings
      return @default_mappings unless @default_mappings.nil?

      mappings = {
        global: {
          read: {
            methods: %i[get],
          },
        },
        topics: {
          write: {
            actions: %w[posts#create],
            params: %i[topic_id],
          },
          update: {
            actions: %w[topics#update topics#status],
            params: %i[topic_id category_id],
          },
          delete: {
            actions: %w[topics#destroy],
          },
          read: {
            actions: %w[topics#show topics#feed topics#posts],
            params: %i[topic_id],
            aliases: {
              topic_id: :id,
            },
          },
          read_lists: {
            actions: list_actions,
            params: %i[category_id],
            aliases: {
              category_id: :category_slug_path_with_id,
            },
          },
          status: {
            actions: %w[topics#status],
            params: %i[topic_id category_id status enabled],
          },
        },
        posts: {
          edit: {
            actions: %w[posts#update],
            params: %i[id],
          },
          delete: {
            actions: %w[posts#destroy],
          },
        },
        tags: {
          list: {
            actions: %w[tags#index],
          },
        },
        categories: {
          list: {
            actions: %w[categories#index],
          },
          show: {
            actions: %w[categories#show],
            params: %i[id],
          },
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
            ],
          },
        },
        users: {
          bookmarks: {
            actions: %w[users#bookmarks],
            params: %i[username],
          },
          sync_sso: {
            actions: %w[admin/users#sync_sso],
            params: %i[sso sig],
          },
          show: {
            actions: %w[users#show],
            params: %i[username external_id external_provider],
          },
          check_emails: {
            actions: %w[users#check_emails],
            params: %i[username],
          },
          update: {
            actions: %w[users#update],
            params: %i[username],
          },
          log_out: {
            actions: %w[admin/users#log_out],
          },
          anonymize: {
            actions: %w[admin/users#anonymize],
          },
          suspend: {
            actions: %w[admin/users#suspend],
          },
          delete: {
            actions: %w[admin/users#destroy],
          },
          list: {
            actions: %w[admin/users#index],
          },
        },
        user_status: {
          read: {
            actions: %w[user_status#get],
          },
          update: {
            actions: %w[user_status#set user_status#clear],
          },
        },
        email: {
          receive_emails: {
            actions: %w[admin/email#handle_mail admin/email#smtp_should_reject],
          },
        },
        invites: {
          create: {
            actions: %w[invites#create],
          },
        },
        badges: {
          create: {
            actions: %w[admin/badges#create],
          },
          show: {
            actions: %w[badges#show],
          },
          update: {
            actions: %w[admin/badges#update],
          },
          delete: {
            actions: %w[admin/badges#destroy],
          },
          list_user_badges: {
            actions: %w[user_badges#username],
            params: %i[username],
          },
          assign_badge_to_user: {
            actions: %w[user_badges#create],
            params: %i[username],
          },
          revoke_badge_from_user: {
            actions: %w[user_badges#destroy],
          },
        },
        groups: {
          manage_groups: {
            actions: %w[groups#members groups#add_members groups#remove_members],
            params: %i[id],
          },
          administer_groups: {
            actions: %w[
              admin/groups#create
              admin/groups#destroy
              groups#show
              groups#update
              groups#index
            ],
          },
        },
        search: {
          show: {
            actions: %w[search#show],
            params: %i[q page],
          },
          query: {
            actions: %w[search#query],
            params: %i[term],
          },
        },
        wordpress: {
          publishing: {
            actions: %w[site#site posts#create topics#update topics#status topics#show],
          },
          commenting: {
            actions: %w[topics#wordpress],
          },
          discourse_connect: {
            actions: %w[admin/users#sync_sso admin/users#log_out admin/users#index users#show],
          },
          utilities: {
            actions: %w[users#create groups#index],
          },
        },
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
          action_data[:urls] = find_urls(
            actions: action_data[:actions],
            methods: action_data[:methods],
          )
        end
      end
    end

    def find_urls(actions:, methods:)
      urls = Set.new

      if actions.present?
        route_sets = [Rails.application.routes]
        Rails::Engine.descendants.each do |engine|
          next if engine == Rails::Application # abstract engine, can't call routes on it
          next if engine == Discourse::Application # equiv. to Rails.application
          route_sets << engine.routes
        end

        route_sets.each do |set|
          engine_mount_path = set.find_script_name({}).presence
          engine_mount_path = nil if engine_mount_path == "/"
          set.routes.each do |route|
            defaults = route.defaults
            action = "#{defaults[:controller].to_s}##{defaults[:action]}"
            path = route.path.spec.to_s.gsub(/\(\.:format\)/, "")
            api_supported_path =
              (
                path.end_with?(".rss") || !route.path.requirements[:format] ||
                  route.path.requirements[:format].match?("json")
              )
            excluded_paths = %w[/new-topic /new-message /exception]

            if actions.include?(action) && api_supported_path && !excluded_paths.include?(path)
              urls << "#{engine_mount_path}#{path} (#{route.verb})"
            end
          end
        end
      end

      methods.each { |method| urls << "* (#{method})" } if methods.present?

      urls.to_a
    end
  end

  def permits?(env)
    RouteMatcher.new(**mapping.except(:urls), allowed_param_values: allowed_parameters).match?(
      env: env,
    )
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
