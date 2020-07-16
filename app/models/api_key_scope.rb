# frozen_string_literal: true

class ApiKeyScope < ActiveRecord::Base
  validates_presence_of :resource
  validates_presence_of :action

  class << self
    def list_actions
      actions = []

      TopTopic.periods.each do |p|
        actions.concat(["list#category_top_#{p}", "list#top_#{p}", "list#top_#{p}_feed"])
      end

      %i[latest unread new top].each { |f| actions.concat(["list#category_#{f}", "list##{f}"]) }

      actions
    end

    def default_mappings
      {
        topics: {
          write: { actions: %w[posts#create topics#feed], params: %i[topic_id] },
          read: { actions: %w[topics#show], params: %i[topic_id], aliases: { topic_id: :id } },
          read_lists: { actions: list_actions, params: %i[category_id], aliases: { category_id: :category_slug_path_with_id } }
        }
      }
    end

    def scope_mappings
      plugin_mappings = DiscoursePluginRegistry.api_key_scope_mappings

      default_mappings.tap do |mappings|
        plugin_mappings.each do |mapping|
          mappings.deep_merge!(mapping)
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
