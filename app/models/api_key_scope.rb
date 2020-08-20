# frozen_string_literal: true

class ApiKeyScope < ActiveRecord::Base
  validates_presence_of :resource
  validates_presence_of :action

  class << self
    def list_actions
      actions = %w[list#category_feed]

      TopTopic.periods.each do |p|
        actions.concat(["list#category_top_#{p}", "list#top_#{p}", "list#top_#{p}_feed"])
      end

      %i[latest unread new top].each { |f| actions.concat(["list#category_#{f}", "list##{f}"]) }

      actions
    end

    def default_mappings
      write_actions = %w[posts#create]
      read_actions = %w[topics#show topics#feed]

      @default_mappings ||= {
        topics: {
          write: { actions: write_actions, params: %i[topic_id], urls: find_urls(write_actions) },
          read: {
            actions: read_actions, params: %i[topic_id],
            aliases: { topic_id: :id }, urls: find_urls(read_actions)
          },
          read_lists: {
            actions: list_actions, params: %i[category_id],
            aliases: { category_id: :category_slug_path_with_id }, urls: find_urls(list_actions)
          }
        }
      }
    end

    def scope_mappings
      plugin_mappings = DiscoursePluginRegistry.api_key_scope_mappings

      default_mappings.tap do |mappings|
        plugin_mappings.each do |mapping|
          mapping[:urls] = find_urls(mapping[:actions])

          mappings.deep_merge!(mapping)
        end
      end
    end

    def find_urls(actions)
      Rails.application.routes.routes.reduce([]) do |memo, route|
        defaults = route.defaults
        action = "#{defaults[:controller].to_s}##{defaults[:action]}"
        path = route.path.spec.to_s.gsub(/\(\.:format\)/, '')
        api_supported_path = path.end_with?('.rss') || route.path.requirements[:format]&.match?('json')
        excluded_paths = %w[/new-topic /new-message /exception]

        memo.tap do |m|
          m << path if actions.include?(action) && api_supported_path && !excluded_paths.include?(path)
        end
      end
    end
  end

  def permits?(route_param)
    path_params = "#{route_param['controller']}##{route_param['action']}"

    mapping[:actions].include?(path_params) && (allowed_parameters.blank? || params_allowed?(route_param))
  end

  private

  def params_allowed?(route_param)
    mapping[:params].all? do |param|
      param_alias = mapping.dig(:aliases, param)
      allowed_values = [allowed_parameters[param.to_s]].flatten
      value = route_param[param.to_s]
      alias_value = route_param[param_alias.to_s]

      return false if value.present? && alias_value.present?

      value = value || alias_value
      value = extract_category_id(value) if param_alias == :category_slug_path_with_id

      allowed_values.blank? || allowed_values.include?(value)
    end
  end

  def mapping
    @mapping ||= self.class.scope_mappings.dig(resource.to_sym, action.to_sym)
  end

  def extract_category_id(category_slug_with_id)
    parts = category_slug_with_id.split('/')

    !parts.empty? && parts.last =~ /\A\d+\Z/ ? parts.pop : nil
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
