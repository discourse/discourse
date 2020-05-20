# frozen_string_literal: true

class ApiKeyScope < ActiveRecord::Base
  def permits?(route_param)
    path_params = "#{route_param['controller']}##{route_param['action']}"

    mapping[:action] == path_params && (allowed_parameters.blank? || params_allowed?(route_param))
  end

  private

  def params_allowed?(route_param)
    mapping[:params].all? do |param|
      param_alias = mapping.dig(:aliases, param)
      allowed_value = allowed_parameters[param.to_s]

      allowed_value.blank? ||
      allowed_value == route_param[param.to_s] ||
      (param_alias.present? && allowed_value == route_param[param_alias.to_s])
    end
  end

  def mapping
    @mapping ||= ApiKey.scope_mappings.dig(resource.to_sym, action.to_sym)
  end
end
