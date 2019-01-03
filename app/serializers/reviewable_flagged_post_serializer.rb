class ReviewableFlaggedPostSerializer < ReviewableSerializer
  target_attributes :cooked, :raw
end
