# frozen_string_literal: true

class TopicPosterSerializer < ApplicationSerializer
  attributes :extras, :description

  has_one :user, serializer: PosterSerializer
  has_one :primary_group, serializer: PrimaryGroupSerializer
  has_one :flair_group, serializer: FlairGroupSerializer
end
