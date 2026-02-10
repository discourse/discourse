# frozen_string_literal: true

class AiSecretSerializer < ApplicationSerializer
  root "ai_secret"

  attributes :id, :name, :secret, :created_at, :updated_at, :used_by

  def secret
    if scope.is_a?(Hash) && scope[:unmask]
      object.secret
    else
      "********"
    end
  end

  def used_by
    @used_by ||= object.used_by.map { |usage| usage.deep_stringify_keys }
  end
end
