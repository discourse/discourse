# frozen_string_literal: true

class TopicPosterSerializer < ApplicationSerializer
  attributes :extras, :description

  has_one :user, serializer: PosterSerializer
  has_one :primary_group, serializer: PrimaryGroupSerializer
  has_one :flair_group, serializer: FlairGroupSerializer

  def include_flair_group?
    (scope || Guardian.new).can_see_flair?
  end
end
