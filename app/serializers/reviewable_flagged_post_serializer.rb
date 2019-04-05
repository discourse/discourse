class ReviewableFlaggedPostSerializer < ReviewableSerializer
  target_attributes :cooked, :raw, :reply_count
end
