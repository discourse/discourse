# frozen_string_literal: true

module Boards
  class CardTagSerializer < ApplicationSerializer
    attributes :id, :name, :slug

    def slug
      object.slug_for_url
    end
  end
end
