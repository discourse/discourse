# frozen_string_literal: true

class ApiKeyScope < ActiveRecord::Base
  validates :resource, presence: true
  validates :action, presence: true

  class << self
    def list_actions
      actions = %w[list#category_feed list#category_default list#latest_feed]

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
            params: %i[category_id],
            path_params: %i[topic_id],
          },
          delete: {
            actions: %w[topics#destroy],
            path_params: %i[topic_id],
            aliases: {
              topic_id: :id,
            },
          },
          recover: {
            actions: %w[topics#recover],
            path_params: %i[topic_id],
          },
          read: {
            actions: %w[topics#show topics#feed topics#posts topics#show_by_external_id],
            path_params: %i[topic_id external_id],
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
            params: %i[category_id status enabled],
            path_params: %i[topic_id],
          },
          change_owner: {
            actions: %w[topics#change_post_owners],
            path_params: %i[topic_id],
          },
        },
        posts: {
          edit: {
            actions: %w[posts#update],
            path_params: %i[id],
          },
          delete: {
            actions: %w[posts#destroy],
            path_params: %i[id],
          },
          recover: {
            actions: %w[posts#recover],
            path_params: %i[post_id],
          },
          list: {
            actions: %w[posts#latest],
          },
        },
        revisions: {
          read: {
            actions: %w[posts#latest_revision posts#revisions],
            path_params: %i[post_id],
          },
          modify: {
            actions: %w[posts#hide_revision posts#show_revision posts#revert],
            path_params: %i[post_id],
          },
          permanently_delete: {
            actions: %w[posts#permanently_delete_revisions],
            path_params: %i[post_id],
          },
        },
        tags: {
          list: {
            actions: %w[tags#index],
          },
        },
        tag_groups: {
          list: {
            actions: %w[tag_groups#index],
          },
          show: {
            actions: %w[tag_groups#show],
            path_params: %i[id],
          },
          create: {
            actions: %w[tag_groups#create],
          },
          update: {
            actions: %w[tag_groups#update],
            path_params: %i[id],
          },
        },
        categories: {
          list: {
            actions: %w[categories#index],
          },
          show: {
            actions: %w[categories#show],
            path_params: %i[id],
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
            path_params: %i[username],
          },
          sync_sso: {
            actions: %w[admin/users#sync_sso],
            params: %i[sso sig],
          },
          show: {
            actions: %w[users#show],
            path_params: %i[username external_id external_provider],
          },
          check_emails: {
            actions: %w[users#check_emails],
            path_params: %i[username],
          },
          create: {
            actions: %w[users#create],
          },
          update: {
            actions: %w[
              users#update
              users#badge_title
              users#pick_avatar
              users#select_avatar
              users#feature_topic
              users#clear_featured_topic
            ],
            path_params: %i[username],
          },
          log_out: {
            actions: %w[admin/users#log_out],
            path_params: %i[user_id],
          },
          anonymize: {
            actions: %w[admin/users#anonymize],
            path_params: %i[user_id],
          },
          suspend: {
            actions: %w[admin/users#suspend],
            path_params: %i[user_id],
          },
          delete: {
            actions: %w[admin/users#destroy],
            path_params: %i[id],
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
          list: {
            actions: %w[badges#index admin/badges#index],
          },
          create: {
            actions: %w[admin/badges#create],
          },
          show: {
            actions: %w[badges#show],
            path_params: %i[id],
          },
          update: {
            actions: %w[admin/badges#update],
            path_params: %i[id],
          },
          delete: {
            actions: %w[admin/badges#destroy],
            path_params: %i[id],
          },
          list_user_badges: {
            actions: %w[user_badges#username],
            path_params: %i[username],
          },
          assign_badge_to_user: {
            actions: %w[user_badges#create],
            params: %i[username],
          },
          revoke_badge_from_user: {
            actions: %w[user_badges#destroy],
            path_params: %i[id],
          },
        },
        groups: {
          manage_groups: {
            actions: %w[groups#members groups#add_members groups#remove_member],
            path_params: %i[id name],
          },
          administer_groups: {
            actions: %w[
              admin/groups#create
              admin/groups#destroy
              groups#show
              groups#update
              groups#index
            ],
            path_params: %i[id name],
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
        logs: {
          messages: {
            actions: [Logster::Web],
          },
        },
      }

      parse_resources!(mappings)
      @default_mappings = mappings
    end

    def restrictable_parameters(mapping)
      (
        Array(mapping&.dig(:params)).map(&:to_sym) | Array(mapping&.dig(:path_params)).map(&:to_sym)
      ).presence
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
            action = "#{defaults[:controller]}##{defaults[:action]}"
            path = route.path.spec.to_s.gsub(/\(\.:format\)/, "")
            api_supported_path =
              path.end_with?(".rss") || !route.path.requirements[:format] ||
                route.path.requirements[:format].match?("json")
            excluded_paths = %w[/new-topic /new-message /exception]

            if actions.include?(action) && api_supported_path && !excluded_paths.include?(path)
              urls << "#{engine_mount_path}#{path} (#{route.verb})"
            end

            if actions.include?(Logster::Web)
              urls << "/logs/messages.json (POST)"
              urls << "/logs/show/:id.json (GET)"
            end
          end
        end
      end

      methods.each { |method| urls << "* (#{method})" } if methods.present?

      urls.to_a
    end
  end

  def permits?(env)
    return false if mapping.nil?

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
#  action             :string           not null
#  allowed_parameters :json
#  resource           :string           not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  api_key_id         :integer          not null
#
# Indexes
#
#  index_api_key_scopes_on_api_key_id  (api_key_id)
#
