# frozen_string_literal: true

class PublishedPageSerializer < ApplicationSerializer
  attributes :id, :slug, :public

  def id
    object.topic_id
  end
end
