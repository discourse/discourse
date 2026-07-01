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
      return false if !can_see_post?(post)

      return true if is_staff?

      if current_user.in_any_groups?(SiteSetting.accept_all_solutions_allowed_groups_map)
        return true
      end

      return true if !topic.private_message? && is_category_group_moderator?(topic.category)

      topic.user_id == current_user.id && !topic.closed && SiteSetting.accept_solutions_topic_author
    end

    def can_unaccept_answer?(topic, post)
      can_accept_answer?(topic, post) ||
        (is_staff? && topic&.topic_answers&.exists?(answer_post_id: post.id))
    end

    def can_create_shared_issue?(topic)
      return false if topic.blank? || !authenticated?
      return false if topic.user_id == current_user.id
      return false if topic.private_message?
      return false if topic.trashed? || topic.closed? || topic.archived?
      return false if topic.solved.present? && !SiteSetting.solved_allow_multiple_solutions
      return false unless topic_in_support_category?(topic)
      return false unless shared_issues_enabled_for_category?(topic)
      return false unless current_user.upcoming_change_enabled?(:enable_solved_shared_issues)
      can_see_topic?(topic)
    end

    def shared_issue_visible?(topic)
      return false if topic.blank?
      return false if topic.private_message?
      return false if topic.trashed? || topic.closed? || topic.archived?
      return false unless topic_in_support_category?(topic)
      return false unless shared_issues_enabled_for_category?(topic)
      unless UpcomingChanges.enabled_for_user?(:enable_solved_shared_issues, current_user)
        return false
      end
      true
    end

    def shared_issues_enabled_for_category?(topic)
      topic.category&.shared_issues_enabled?
    end

    def topic_in_support_category?(topic)
      return false if topic.category_id.blank?

      if !DiscourseSolved::AcceptedAnswerCache.allowed
        DiscourseSolved::AcceptedAnswerCache.reset_accepted_answer_cache
      end

      DiscourseSolved::AcceptedAnswerCache.allowed.include?(topic.category_id)
    end
  end
end
