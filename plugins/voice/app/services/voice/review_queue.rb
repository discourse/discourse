# frozen_string_literal: true

module Voice
  # Mirrors Chat::ReviewQueue for flags raised against a room participant.
  # Only the "something else" (notify_moderators) flag is supported: rooms
  # have no post or message to attach a canned flag reason to, so every flag
  # carries a custom message that is delivered to moderators as a companion
  # PM, alongside the reviewable itself.
  class ReviewQueue
    def flag_user(room, target_user, guardian, flag_type_id, opts = {})
      result = { success: false, errors: [] }

      guardian.ensure_can_flag_voice_user!(room, target_user)

      session = Voice::Session.where(room: room, user: target_user).order(joined_at: :desc).first

      if session.blank?
        result[:errors] << I18n.t("voice.errors.flag_target_never_joined")
        return result
      end

      existing_reviewable = Reviewable.includes(:reviewable_scores).find_by(target: session)

      if !can_flag_again?(existing_reviewable, guardian.user)
        result[:errors] << I18n.t("voice.errors.flag_already_handled")
        return result
      end

      pm_creator = companion_pm_creator(room, target_user, guardian.user, opts)
      post = pm_creator.create

      if pm_creator.errors.present?
        pm_creator.errors.full_messages.each { |msg| result[:errors] << msg }
        return result
      end

      reviewable =
        ReviewableVoiceUser.needs_review!(
          created_by: guardian.user,
          target: session,
          reviewable_by_moderator: true,
        )
      reviewable.update!(
        target_created_by: target_user,
        payload: {
          message: opts[:message],
          room_id: room.id,
          room_name: room.name,
          room_slug: room.slug,
        },
      )
      reviewable.add_score(guardian.user, flag_type_id, meta_topic_id: post&.topic_id)

      result[:success] = true
      result[:reviewable] = reviewable
      result
    end

    private

    def can_flag_again?(reviewable, flagger)
      return true if reviewable.blank?

      reviewable.reviewable_scores.none? { |score| score.user_id == flagger.id && score.pending? }
    end

    def companion_pm_creator(room, target_user, flagger, opts)
      title =
        I18n.t(
          "voice.reviewable_score_types.notify_moderators.pm_title",
          username: target_user.username,
          locale: SiteSetting.default_locale,
        )

      body =
        I18n.t(
          "voice.reviewable_score_types.notify_moderators.pm_body",
          message: opts[:message],
          username: target_user.username,
          room_name: room.name,
          link: "#{Discourse.base_url}/voice/r/#{room.slug}",
          locale: SiteSetting.default_locale,
        )

      PostCreator.new(
        flagger,
        archetype: Archetype.private_message,
        title: title.truncate(SiteSetting.max_topic_title_length, separator: /\s/),
        raw: body,
        subtype: TopicSubtype.notify_moderators,
        target_group_names: [Group[:moderators].name],
      )
    end
  end
end
