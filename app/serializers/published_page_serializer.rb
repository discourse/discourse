# frozen_string_literal: true

class PublishedPageSerializer < ApplicationSerializer
  attributes :id, :slug

  def id
    object.topic_id
  end
end
