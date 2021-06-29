# frozen_string_literal: true

class FlairGroupSerializer < ApplicationSerializer
  attributes :id, :name, :flair_url, :flair_bg_color, :flair_color
end
