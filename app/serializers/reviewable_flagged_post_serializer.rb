class ReviewableFlaggedPostSerializer < ReviewableSerializer
  target_attributes :cooked, :raw, :reply_count, :version
  attributes :blank_post, :post_updated_at

  def post_updated_at
    object.target&.updated_at
  end

  def blank_post
    true
  end

  def include_blank_post?
    object.target.blank?
  end
end
