# frozen_string_literal: true

module DiscourseAi
  module GuardianExtensions
    def can_see_summary?(target)
      return false if !SiteSetting.ai_summarization_enabled

      if target.class == Topic && target.private_message?
        allowed =
          SiteSetting.ai_pm_summarization_allowed_groups_map.any? do |group_id|
            user.group_ids.include?(group_id)
          end

        return false if !allowed
      end

      has_cached_summary =
        AiSummary.exists?(target: target, summary_type: AiSummary.summary_types[:complete])
      return has_cached_summary if user.nil?

      has_cached_summary || can_request_summary?
    end

    def can_see_gists?
      return false if !SiteSetting.ai_summarization_enabled
      return false if !SiteSetting.ai_summary_gists_enabled

      if (ai_persona = AiPersona.find_by(id: SiteSetting.ai_summary_gists_persona)).blank?
        return false
      end
      persona_groups = ai_persona.allowed_group_ids.to_a
      return true if persona_groups.include?(Group::AUTO_GROUPS[:everyone])
      return false if anonymous?

      persona_groups.any? { |group_id| user.group_ids.include?(group_id) }
    end

    def can_request_summary?
      return false if anonymous?

      user_group_ids = user.group_ids
      if (ai_persona = AiPersona.find_by(id: SiteSetting.ai_summarization_persona)).blank?
        return false
      end

      ai_persona.allowed_group_ids.to_a.any? { |group_id| user.group_ids.include?(group_id) }
    end

    def can_debug_ai_bot_conversation?(target)
      return false if anonymous?

      return false if !can_see?(target)

      if !SiteSetting.discourse_ai_enabled || !SiteSetting.ai_bot_enabled ||
           !SiteSetting.ai_bot_debugging_allowed_groups_map.any?
        return false
      end

      user.in_any_groups?(SiteSetting.ai_bot_debugging_allowed_groups_map)
    end

    def can_share_ai_bot_conversation?(target)
      return false if anonymous?

      if !SiteSetting.discourse_ai_enabled || !SiteSetting.ai_bot_enabled ||
           !SiteSetting.ai_bot_public_sharing_allowed_groups_map.any?
        return false
      end

      return false if !user.in_any_groups?(SiteSetting.ai_bot_public_sharing_allowed_groups_map)

      # In future we may add other valid targets for AI conversation sharing,
      # for now we only support topics.
      if target.is_a?(Topic)
        return false if !target.private_message?
        return false if target.topic_allowed_groups.exists?
        allowed_user_ids = target.topic_allowed_users.pluck(:user_id)

        # not in PM
        return false if !allowed_user_ids.include?(user.id)

        # other people in PM
        return false if allowed_user_ids.any? { |id| id > 0 && id != user.id }

        # no bot in the PM
        bot_ids = DiscourseAi::AiBot::EntryPoint.all_bot_ids
        return false if allowed_user_ids.none? { |id| bot_ids.include?(id) }

        # other content in PM
        return false if target.posts.where("user_id > 0 and user_id <> ?", user.id).exists?
      else
        return false
      end

      true
    end

    def can_destroy_shared_ai_bot_conversation?(conversation)
      return false if anonymous?

      conversation.user_id == user.id || is_admin?
    end
  end
end
