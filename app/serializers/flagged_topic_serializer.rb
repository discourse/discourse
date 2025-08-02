# frozen_string_literal: true

class FlaggedTopicSerializer < ActiveModel::Serializer
  attributes :id,
             :title,
             :fancy_title,
             :slug,
             :archived,
             :closed,
             :visible,
             :archetype,
             :relative_url
end
