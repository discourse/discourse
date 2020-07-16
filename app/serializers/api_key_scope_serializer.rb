# frozen_string_literal: true

class ApiKeyScopeSerializer < ApplicationSerializer

  attributes :resource,
             :action,
             :parameters,
             :allowed_parameters

  def parameters
    ApiKeyScope.scope_mappings.dig(object.resource.to_sym, object.action.to_sym, :params).to_a
  end
end
