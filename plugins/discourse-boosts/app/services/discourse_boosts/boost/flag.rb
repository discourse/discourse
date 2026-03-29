# frozen_string_literal: true

module DiscourseBoosts
  class Boost::Flag
    include Service::Base

    params do
      attribute :boost_id, :integer
      attribute :flag_type_id, :integer
      attribute :message, :string
      attribute :take_action, :boolean
      attribute :queue_for_review, :boolean

      validates :boost_id, presence: true
      validates :flag_type_id,
                presence: true,
                inclusion: {
                  in: -> do
                    ::Flag.enabled.where("'DiscourseBoosts::Boost' = ANY(applies_to)").pluck(:id)
                  end,
                }
    end

    model :boost
    policy :can_flag_boost
    model :existing_reviewable, optional: true
    policy :can_flag_again

    transaction do
      model :companion_post, :create_companion_pm, optional: true
      model :reviewable, :create_reviewable
      step :add_score
      only_if(:taking_action) { step :perform_take_action }
    end

    private

    def fetch_boost(params:)
      DiscourseBoosts::Boost.includes(:post, :user).find_by(id: params.boost_id)
    end

    def can_flag_boost(guardian:, boost:, params:)
      guardian.user.present? && !guardian.user.silenced? && boost.user_id != guardian.user.id &&
        guardian.can_see?(boost.post) &&
        (SiteSetting.allow_flagging_staff || !boost.user&.staff?) &&
        (!params.take_action && !params.queue_for_review || guardian.is_staff?)
    end

    def fetch_existing_reviewable(boost:)
      Reviewable.includes(:reviewable_scores).find_by(target: boost)
    end

    def can_flag_again(guardian:, existing_reviewable:, params:)
      return true if existing_reviewable.blank?

      scores = existing_reviewable.reviewable_scores
      return false if scores.any? { |rs| rs.user == guardian.user && rs.pending? }
      if scores.any? { |rs| rs.reviewable_score_type == params.flag_type_id && rs.pending? }
        return false
      end

      existing_reviewable.pending? ||
        existing_reviewable.updated_at < SiteSetting.cooldown_hours_until_reflag.to_i.hours.ago
    end

    def create_companion_pm(boost:, params:, guardian:)
      return if params.message.blank?

      flag_type_id = params.flag_type_id
      is_notify_moderators =
        ReviewableScore.types.slice(:notify_moderators).values.include?(flag_type_id)
      is_illegal = ReviewableScore.types.slice(:illegal).values.include?(flag_type_id)
      return unless is_notify_moderators || is_illegal

      i18n_key = is_notify_moderators ? "notify_moderators" : "illegal"

      title =
        I18n.t("discourse_boosts.flagging.#{i18n_key}.pm_title", locale: SiteSetting.default_locale)

      body =
        I18n.t(
          "discourse_boosts.flagging.#{i18n_key}.pm_body",
          message: params.message,
          link: boost.post.full_url,
          locale: SiteSetting.default_locale,
        )

      creator =
        PostCreator.new(
          guardian.user,
          archetype: Archetype.private_message,
          title: title.truncate(SiteSetting.max_topic_title_length, separator: /\s/),
          raw: body,
          subtype: TopicSubtype.notify_moderators,
          target_group_names: [Group[:moderators].name],
        )

      post = creator.create

      if creator.errors.present?
        creator.errors.full_messages.each { |msg| fail!(message: msg) }
        return
      end

      post
    end

    def create_reviewable(boost:, params:, guardian:)
      DiscourseBoosts::ReviewableBoost.needs_review!(
        created_by: guardian.user,
        target: boost,
        topic: boost.post.topic,
        target_created_by: boost.user,
        reviewable_by_moderator: true,
        potential_spam: params.flag_type_id == ReviewableScore.types[:spam],
        payload: {
          boost_cooked: boost.cooked,
        },
      )
    end

    def add_score(reviewable:, guardian:, params:, companion_post:)
      queued_for_review = !!params.queue_for_review

      reviewable.add_score(
        guardian.user,
        params.flag_type_id,
        meta_topic_id: companion_post&.topic_id,
        take_action: params.take_action,
        reason: queued_for_review ? "boost_queued_by_staff" : nil,
        force_review: queued_for_review,
      )
    end

    def taking_action(params:)
      params.take_action
    end

    def perform_take_action(reviewable:, guardian:)
      reviewable.perform(guardian.user, :agree_and_delete)
    end
  end
end
