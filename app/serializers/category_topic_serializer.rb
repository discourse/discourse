require_dependency 'pinned_check'

class CategoryTopicSerializer < ListableTopicSerializer

  attributes :visible, :closed, :archived, :pinned

  def pinned
    PinnedCheck.new(object, object.user_data).pinned?
  end

end
