class HiddenTopicViewSerializer < ApplicationSerializer
  attributes :view_hidden?

  has_one :group, serializer: BasicGroupSerializer, root: false, embed: :objects

  def view_hidden?
    true
  end

  def group
    object.access_topic_via_group
  end
end
