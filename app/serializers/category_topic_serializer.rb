require_dependency 'pinned_check'

class CategoryTopicSerializer < ListableTopicSerializer

  attributes :visible, :closed, :archived, :pinned
  has_one :category

  def pinned
    PinnedCheck.new(object, object.user_data).pinned?
  end

end
