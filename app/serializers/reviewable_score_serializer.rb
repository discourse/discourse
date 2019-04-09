require_dependency 'reviewable_score_type_serializer'

class ReviewableScoreSerializer < ApplicationSerializer

  attributes :id, :score, :agree_stats, :status, :created_at, :reviewed_at
  has_one :user, serializer: BasicUserSerializer, root: 'users'
  has_one :score_type, serializer: ReviewableScoreTypeSerializer
  has_one :reviewable_conversation, serializer: ReviewableConversationSerializer
  has_one :reviewed_by, serializer: BasicUserSerializer, root: 'users'

  def agree_stats
    {
      agreed: user.user_stat.flags_agreed,
      disagreed: user.user_stat.flags_disagreed,
      ignored: user.user_stat.flags_ignored
    }
  end

end
