# frozen_string_literal: true

require_relative "./rule_serializer"

class DiscourseChatIntegration::ChannelSerializer < ApplicationSerializer
  attributes :id, :provider, :error_key, :error_info, :data, :rules

  def rules
    object.rules.order_by_precedence.map do |rule|
      DiscourseChatIntegration::RuleSerializer.new(rule, root: false)
    end
  end
end
