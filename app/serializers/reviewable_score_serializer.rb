# frozen_string_literal: true

class ReviewableScoreSerializer < ApplicationSerializer

  attributes :id, :score, :agree_stats, :status, :reason, :created_at, :reviewed_at
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

  def reason
    return unless object.reason

    if text = I18n.t("reviewables.reasons.#{object.reason}", base_url: Discourse.base_url, default: nil)
      # Create a convenient link to any site settings if the user is staff
      settings_url = "#{Discourse.base_url}/admin/site_settings/category/all_results?filter="

      text.gsub!(/`[a-z_]+`/) do |m|
        if scope.is_staff?
          setting = m[1..-2]
          "<a href=\"#{settings_url}#{setting}\">#{setting.gsub('_', ' ')}</a>"
        else
          m.gsub('_', ' ')
        end
      end
    end

    text
  end

  def include_reason?
    reason.present?
  end

end
