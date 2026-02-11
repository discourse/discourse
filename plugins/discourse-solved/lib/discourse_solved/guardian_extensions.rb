# frozen_string_literal: true

module DiscourseSolved
  module GuardianExtensions
    def allow_accepted_answers?(topic)
      return true if SiteSetting.allow_solved_on_all_topics

      if topic.private_message?
        return(
          SiteSetting.allow_solved_in_groups_map.present? &&
            topic.allowed_groups.exists?(id: SiteSetting.allow_solved_in_groups_map)
        )
      end

      solved_enabled_for_category?(topic.category_id, topic.tags.map(&:name))
    end

    def solved_enabled_for_category?(category_id, tag_names = [])
      return true if SiteSetting.allow_solved_on_all_topics

      if SiteSetting.enable_solved_tags.present? && tag_names.present?
        return true if (tag_names & SiteSetting.enable_solved_tags.split("|")).present?
      end

      return false if category_id.blank?

      if !DiscourseSolved::AcceptedAnswerCache.allowed
        DiscourseSolved::AcceptedAnswerCache.reset_accepted_answer_cache
      end

      DiscourseSolved::AcceptedAnswerCache.allowed.include?(category_id)
    end

    def can_accept_answer?(topic, post)
      return false if !authenticated?
      return false if !topic || !post || post.post_number <= 1 || post.whisper?
      return false if !allow_accepted_answers?(topic)

      return true if is_staff?

      if current_user.in_any_groups?(SiteSetting.accept_all_solutions_allowed_groups_map)
        return true
      end

      return true if !topic.private_message? && is_category_group_moderator?(topic.category)

      topic.user_id == current_user.id && !topic.closed && SiteSetting.accept_solutions_topic_author
    end
  end
end
