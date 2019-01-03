require_dependency 'reviewable_score_type_serializer'

class ReviewableScoreSerializer < ApplicationSerializer

  attributes :id, :score, :agree_stats
  has_one :user, serializer: BasicUserSerializer, root: 'users'
  has_one :score_type, serializer: ReviewableScoreTypeSerializer
  has_one :reviewable_conversation, serializer: ReviewableConversationSerializer

  def agree_stats
    {
      agreed: user.user_stat.flags_agreed,
      disagreed: user.user_stat.flags_disagreed,
      ignored: user.user_stat.flags_ignored
    }
  end

end
