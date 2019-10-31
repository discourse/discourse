# frozen_string_literal: true

class FlaggedTopicSerializer < ActiveModel::Serializer
  root 'flagged_topic'

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
