# frozen_string_literal: true

require_dependency "reviewable_flagged_post_serializer"

class ReviewableAiPostSerializer < ReviewableFlaggedPostSerializer
  payload_attributes :accuracies
end
