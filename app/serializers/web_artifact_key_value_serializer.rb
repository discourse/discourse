# frozen_string_literal: true

class WebArtifactKeyValueSerializer < ApplicationSerializer
  attributes :id, :key, :value, :public, :user_id, :created_at, :updated_at

  def include_value?
    !options[:keys_only]
  end
end
