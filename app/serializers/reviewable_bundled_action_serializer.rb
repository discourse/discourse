class ReviewableBundledActionSerializer < ApplicationSerializer
  attributes :id, :icon, :label
  has_many :actions, serializer: ReviewableActionSerializer, root: 'actions'

  def label
    I18n.t(object.label)
  end
end
