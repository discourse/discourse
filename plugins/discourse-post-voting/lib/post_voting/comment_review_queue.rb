# frozen_string_literal: true
module PostVoting
  class CommentReviewQueue
    def flag_comment(comment, guardian, flag_type_id, opts = {})
      result = { success: false, errors: [] }
      is_notify_user_type = ReviewableScore.types.slice(:notify_user).values.include?(flag_type_id)
      is_notify_moderators_type =
        ReviewableScore.types.slice(:notify_moderators).values.include?(flag_type_id)
      is_notify_type = is_notify_user_type || is_notify_moderators_type

      guardian.ensure_can_flag_post_voting_comment!(comment)
      guardian.ensure_can_flag_post_voting_comment_as!(comment, flag_type_id, opts)

      existing_reviewable = Reviewable.includes(:reviewable_scores).find_by(target: comment)

      if !can_flag_again?(existing_reviewable, comment, guardian.user, flag_type_id)
        result[:errors] << I18n.t("post_voting.reviewables.comment_already_handled")
        return result
      end

      payload = { comment_cooked: comment.cooked }

      if opts[:comment].present? && is_notify_type
        creator = companion_pm_creator(comment, guardian.user, flag_type_id, opts)
        post = creator.create

        if creator.errors.present?
          creator.errors.full_messages.each { |msg| result[:errors] << msg }
          return result
        end
      end

      queued_for_review = !!ActiveRecord::Type::Boolean.new.deserialize(opts[:queue_for_review])

      if !is_notify_user_type
        reviewable =
          ReviewablePostVotingComment.needs_review!(
            created_by: guardian.user,
            target: comment,
            reviewable_by_moderator: true,
            potential_spam: flag_type_id == ReviewableScore.types[:spam],
            topic: comment.post.topic,
            payload: payload,
          )
        reviewable.update(target_created_by: comment.user)
        score =
          reviewable.add_score(
            guardian.user,
            flag_type_id,
            meta_topic_id: post&.topic_id,
            take_action: opts[:take_action],
            reason: queued_for_review ? "post_voting_comment_queued_by_staff" : nil,
            force_review: queued_for_review,
          )

        if opts[:take_action]
          reviewable.perform(guardian.user, :agree_and_delete)
        else
          enforce_auto_silence_threshold(reviewable)
        end
      end

      result.tap do |r|
        r[:success] = true
        r[:reviewable] = reviewable if !is_notify_user_type
      end
    end

    private

    def enforce_auto_silence_threshold(reviewable)
      auto_silence_duration = SiteSetting.chat_auto_silence_from_flags_duration
      return if auto_silence_duration.zero?
      return if reviewable.score <= Chat::ReviewableMessage.score_to_silence_user

      user = reviewable.target_created_by
      return unless user
      return if user.admin?
      return if user.silenced?

      UserSilencer.silence(
        user,
        Discourse.system_user,
        silenced_till: auto_silence_duration.minutes.from_now,
        reason: I18n.t("post_voting.comment.errors.auto_silence_from_flags"),
      )
    end

    def companion_pm_creator(comment, flagger, flag_type_id, opts)
      notifying_user = flag_type_id == ReviewableScore.types[:notify_user]

      i18n_key = notifying_user ? "notify_user" : "notify_moderators"

      title =
        I18n.t(
          "post_voting.comment.reviewable_score_types.#{i18n_key}.comment_pm_title",
          locale: SiteSetting.default_locale,
        )

      body =
        I18n.t(
          "post_voting.comment.reviewable_score_types.#{i18n_key}.comment_pm_body",
          comment: opts[:comment],
          link: comment.full_url,
          locale: SiteSetting.default_locale,
        )

      create_args = {
        archetype: Archetype.private_message,
        title: title.truncate(SiteSetting.max_topic_title_length, separator: /\s/),
        raw: body,
      }

      if notifying_user
        create_args[:subtype] = TopicSubtype.notify_user
        create_args[:target_usernames] = comment.user.username

        create_args[:is_warning] = opts[:is_warning] if flagger.staff?
      else
        create_args[:subtype] = TopicSubtype.notify_moderators
        create_args[:target_group_names] = [Group[:moderators].name]
      end

      PostCreator.new(flagger, create_args)
    end

    def can_flag_again?(reviewable, comment, flagger, flag_type_id)
      return true if reviewable.blank?

      flagger_has_pending_flags =
        reviewable.reviewable_scores.any? { |rs| rs.user == flagger && rs.pending? }

      if !flagger_has_pending_flags && flag_type_id == ReviewableScore.types[:notify_moderators]
        return true
      end

      flag_used =
        reviewable.reviewable_scores.any? do |rs|
          rs.reviewable_score_type == flag_type_id && rs.pending?
        end
      handled_recently =
        !(
          reviewable.pending? ||
            reviewable.updated_at < SiteSetting.cooldown_hours_until_reflag.to_i.hours.ago
        )
      edited_since_last_review = comment && comment.updated_at > reviewable.updated_at

      !flag_used && !flagger_has_pending_flags && (!handled_recently || edited_since_last_review)
    end
  end
end
