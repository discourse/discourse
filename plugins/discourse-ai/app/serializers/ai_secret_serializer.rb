# frozen_string_literal: true

class AiSecretSerializer < ApplicationSerializer
  root "ai_secret"

  attributes :id, :name, :secret, :created_at, :updated_at

  def secret
    if scope.is_a?(Hash) && scope[:unmask]
      object.secret
    else
      "********"
    end
  end
end
