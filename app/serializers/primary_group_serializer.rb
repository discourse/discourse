# frozen_string_literal: true

class PrimaryGroupSerializer < ApplicationSerializer
  root 'primary_group'

  attributes :id, :name, :flair_url, :flair_bg_color, :flair_color
end
