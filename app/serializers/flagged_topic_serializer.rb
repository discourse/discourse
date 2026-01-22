# frozen_string_literal: true

class FlaggedTopicSerializer < ApplicationSerializer
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
