# frozen_string_literal: true

class ApiKeyScopeSerializer < ApplicationSerializer
  attributes :resource, :action, :parameters, :urls, :allowed_parameters, :key

  def parameters
    ApiKeyScope.scope_mappings.dig(object.resource.to_sym, object.action.to_sym, :params).to_a
  end

  def urls
    ApiKeyScope.scope_mappings.dig(object.resource.to_sym, object.action.to_sym, :urls).to_a
  end

  def action
    object.action.to_s.gsub("_", " ")
  end

  def key
    object.action
  end
end
