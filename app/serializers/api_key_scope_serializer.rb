# frozen_string_literal: true

class ApiKeyScopeSerializer < ApplicationSerializer

  attributes :resource,
             :action,
             :parameters,
             :allowed_parameters

  def parameters
    ApiKey::SCOPE_MAPPINGS.dig(object.resource.to_sym, object.action.to_sym, :params).to_a
  end
end
