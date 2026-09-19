# frozen_string_literal: true

class TagLocalizationSerializer < ApplicationSerializer
  attributes :id, :tag_id, :locale, :name, :description, :description_cooked
end
