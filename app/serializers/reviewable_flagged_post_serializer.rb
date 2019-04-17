class ReviewableFlaggedPostSerializer < ReviewableSerializer
  target_attributes :cooked, :raw, :reply_count
  attributes :blank_post

  def blank_post
    true
  end

  def include_blank_post?
    object.target.blank?
  end
end
