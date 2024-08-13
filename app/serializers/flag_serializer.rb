# frozen_string_literal: true

class FlagSerializer < ApplicationSerializer
  attributes :id, :name, :name_key, :description, :applies_to, :position, :require_message, :enabled
end
