# frozen_string_literal: true

class ApiKeyScope < ActiveRecord::Base
  validates_presence_of :resource
  validates_presence_of :action

  def permits?(route_param)
    path_params = "#{route_param['controller']}##{route_param['action']}"

    mapping[:actions].include?(path_params) && (allowed_parameters.blank? || params_allowed?(route_param))
  end

  private

  def params_allowed?(route_param)
    mapping[:params].all? do |param|
      param_alias = mapping.dig(:aliases, param)
      allowed_value = allowed_parameters[param.to_s]
      value = route_param[param.to_s]
      alias_value = route_param[param_alias.to_s]

      return false if value.present? && alias_value.present?

      value = value || alias_value
      value = extract_category_id(value) if param_alias == :category_slug_path_with_id

      allowed_value.blank? || allowed_value == value
    end
  end

  def mapping
    @mapping ||= ApiKey.scope_mappings.dig(resource.to_sym, action.to_sym)
  end

  def extract_category_id(category_slug_with_id)
    parts = category_slug_with_id.split('/')

    !parts.empty? && parts.last =~ /\A\d+\Z/ ? parts.pop : nil
  end
end
