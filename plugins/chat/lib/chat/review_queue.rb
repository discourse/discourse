# frozen_string_literal: true

# Acceptable options:
#   - message: Used when the flag type is notify_user or notify_moderators and we have to create
#     a separate PM.
#   - is_warning: Staff can send warnings when using the notify_user flag.
#   - take_action: Automatically approves the created reviewable and deletes the chat message.
#   - queue_for_review: Adds a special reason to the reviewable score and creates the reviewable using
#     the force_review option.

module Chat
  class ReviewQueue
    def flag_message(chat_message, guardian, flag_type_id, opts = {})
      result = { success: false, errors: [] }

      is_notify_type =
        ReviewableScore.types.slice(:notify_user, :notify_moderators).values.include?(flag_type_id)
      is_dm = chat_message.chat_channel.direct_message_channel?

      raise Discourse::InvalidParameters.new(:flag_type) if is_dm && is_notify_type

      guardian.ensure_can_flag_chat_message!(chat_message)
      guardian.ensure_can_flag_message_as!(chat_message, flag_type_id, opts)

      existing_reviewable = Reviewable.includes(:reviewable_scores).find_by(target: chat_message)

      if !can_flag_again?(existing_reviewable, chat_message, guardian.user, flag_type_id)
        result[:errors] << I18n.t("chat.reviewables.message_already_handled")
        return result
      end

      payload = { message_cooked: chat_message.cooked }

      if opts[:message].present? && !is_dm && is_notify_type
        creator = companion_pm_creator(chat_message, guardian.user, flag_type_id, opts)
        post = creator.create

        if creator.errors.present?
          creator.errors.full_messages.each { |msg| result[:errors] << msg }
          return result
        end
      elsif is_dm
        transcript = find_or_create_transcript(chat_message, guardian.user, existing_reviewable)
        payload[:transcript_topic_id] = transcript.topic_id if transcript
      end

      queued_for_review = !!ActiveRecord::Type::Boolean.new.deserialize(opts[:queue_for_review])

      if !is_notify_type
        reviewable =
          Chat::ReviewableMessage.needs_review!(
            created_by: guardian.user,
            target: chat_message,
            reviewable_by_moderator: true,
            potential_spam: flag_type_id == ReviewableScore.types[:spam],
            payload: payload,
          )
        reviewable.update(target_created_by: chat_message.user)
        score =
          reviewable.add_score(
            guardian.user,
            flag_type_id,
            meta_topic_id: post&.topic_id,
            take_action: opts[:take_action],
            reason: queued_for_review ? "chat_message_queued_by_staff" : nil,
            force_review: queued_for_review,
          )

        if opts[:take_action]
          reviewable.perform(guardian.user, :agree_and_delete)
          Chat::Publisher.publish_delete!(chat_message.chat_channel, chat_message)
        else
          enforce_auto_silence_threshold(reviewable)
          Chat::Publisher.publish_flag!(chat_message, guardian.user, reviewable, score)
        end
      end

      result.tap do |r|
        r[:success] = true
        r[:reviewable] = reviewable if !is_notify_type
      end
    end

    private

    def enforce_auto_silence_threshold(reviewable)
      auto_silence_duration = SiteSetting.chat_auto_silence_from_flags_duration
      return if auto_silence_duration.zero?
      return if reviewable.score <= Chat::ReviewableMessage.score_to_silence_user

      user = reviewable.target_created_by
      return if user.admin?
      return unless user
      return if user.silenced?

      UserSilencer.silence(
        user,
        Discourse.system_user,
        silenced_till: auto_silence_duration.minutes.from_now,
        reason: I18n.t("chat.errors.auto_silence_from_flags"),
      )
    end

    def companion_pm_creator(chat_message, flagger, flag_type_id, opts)
      notifying_user = flag_type_id == ReviewableScore.types[:notify_user]

      i18n_key = notifying_user ? "notify_user" : "notify_moderators"

      title =
        I18n.t(
          "reviewable_score_types.#{i18n_key}.chat_pm_title",
          channel_name: chat_message.chat_channel.title(flagger),
          locale: SiteSetting.default_locale,
        )

      body =
        I18n.t(
          "reviewable_score_types.#{i18n_key}.chat_pm_body",
          message: opts[:message],
          link: chat_message.full_url,
          locale: SiteSetting.default_locale,
        )

      create_args = {
        archetype: Archetype.private_message,
        title: title.truncate(SiteSetting.max_topic_title_length, separator: /\s/),
        raw: body,
      }

      if notifying_user
        create_args[:subtype] = TopicSubtype.notify_user
        create_args[:target_usernames] = chat_message.user.username

        create_args[:is_warning] = opts[:is_warning] if flagger.staff?
      else
        create_args[:subtype] = TopicSubtype.notify_moderators
        create_args[:target_group_names] = [Group[:moderators].name]
      end

      PostCreator.new(flagger, create_args)
    end

    def find_or_create_transcript(chat_message, flagger, existing_reviewable)
      previous_message_ids =
        Chat::Message
          .where(chat_channel: chat_message.chat_channel)
          .where("id < ?", chat_message.id)
          .order("created_at DESC")
          .limit(10)
          .pluck(:id)
          .reverse

      return if previous_message_ids.empty?

      service =
        Chat::TranscriptService.new(
          chat_message.chat_channel,
          Discourse.system_user,
          messages_or_ids: previous_message_ids,
        )

      title =
        I18n.t(
          "chat.reviewables.direct_messages.transcript_title",
          channel_name: chat_message.chat_channel.title(flagger),
          locale: SiteSetting.default_locale,
        )

      body =
        I18n.t(
          "chat.reviewables.direct_messages.transcript_body",
          transcript: service.generate_markdown,
          locale: SiteSetting.default_locale,
        )

      create_args = {
        archetype: Archetype.private_message,
        title: title.truncate(SiteSetting.max_topic_title_length, separator: /\s/),
        raw: body,
        subtype: TopicSubtype.notify_moderators,
        target_group_names: [Group[:moderators].name],
      }

      PostCreator.new(Discourse.system_user, create_args).create
    end

    def can_flag_again?(reviewable, message, flagger, flag_type_id)
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

      latest_revision = message.revisions.last
      edited_since_last_review =
        latest_revision && latest_revision.updated_at > reviewable.updated_at

      !flag_used && !flagger_has_pending_flags && (!handled_recently || edited_since_last_review)
    end
  end
end
