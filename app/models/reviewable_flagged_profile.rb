# frozen_string_literal: true

class ReviewableFlaggedProfile < Reviewable
  include ReviewableActionBuilder

  has_many :upload_references, as: :target, dependent: :destroy

  def self.additional_args(params)
    ReviewableActionBuilder.penalty_args(params)
  end

  def capture_profile!(profile, potentially_illegal: potentially_illegal?)
    user = profile.user
    avatar = user.uploaded_avatar
    header = profile.profile_background_upload
    card_background = profile.card_background_upload
    self.version += 1 if reopened
    update!(
      potentially_illegal:,
      payload: {
        username: user.username,
        name: (user.name if SiteSetting.enable_names?),
        title: user.title,
        bio: profile.bio_raw,
        location: profile.location,
        website: profile.website,
        profile_fields: public_field_snapshot(user),
        profile_header_url: (Discourse.store.cdn_url(header.url) if header),
        card_background_url: (Discourse.store.cdn_url(card_background.url) if card_background),
        avatar_url: avatar ? Discourse.store.cdn_url(avatar.url) : user.small_avatar_url,
      }.compact,
    )
    UploadReference.ensure_exist!(
      upload_ids:
        [avatar&.id, header&.id, card_background&.id] + Upload.extract_upload_ids(profile.bio_raw),
      target_type: self.class.polymorphic_name,
      target_id: id,
    )
  end

  def title_for_notification(user)
    I18n.t("js.review.types.reviewable_flagged_profile.title", locale: user.effective_locale)
  end

  def clear_snapshot!(note_key)
    update!(payload: {}, version: version + 1)
    upload_references.delete_all
    clear_mention_titles!
    ignore_with_note(note_key) if pending?
  end

  def scores_for_decision
    return reviewable_scores.select(&:pending?) if pending?

    reopened_at =
      reviewable_histories
        .filter_map { |history| history.created_at if history.transitioned? && history.pending? }
        .max
    return reviewable_scores unless reopened_at

    reviewable_scores.select { |score| score.created_at >= reopened_at }
  end

  def remove_pending_flags_by!(reporter)
    return if reviewable_scores.pending.where(user: reporter).delete_all.zero?

    increment_version!
    ignore_with_note("reviewables.last_reporter_deleted") unless reviewable_scores.pending.exists?
    recalculate_score
  end

  def build_combined_actions(actions, guardian, _args)
    return unless pending? && guardian.is_staff?

    agree =
      actions.add_bundle("#{id}-agree", icon: "thumbs-up", label: "reviewables.actions.agree.title")
    build_action(actions, :agree_profile_flag, icon: "far-eye", bundle: agree)
    if guardian.can_remove_profile_content?(target_user)
      build_action(
        actions,
        :remove_profile_content,
        icon: "trash-can",
        bundle: agree,
        confirm: :destructive,
        dsa_classification_required: true,
      )
    end
    build_penalty_actions(
      actions,
      bundle: agree,
      silence: :silence_user,
      suspend: :suspend_user,
      silence_options: {
        translation_prefix: "reviewables.actions.agree_and_silence",
      },
      suspend_options: {
        translation_prefix: "reviewables.actions.agree_and_suspend",
      },
      dsa_classification_required: true,
    )
    agree.actions.first.label = agree.label if agree.actions.one?

    disagree =
      actions.add_bundle(
        "#{id}-disagree",
        icon: "far-eye",
        label: "reviewables.actions.disagree_bundle.title",
      )
    build_action(actions, :dismiss_profile_flag, icon: "thumbs-down", bundle: disagree)
    build_action(actions, :ignore, icon: "xmark", bundle: disagree)
  end

  def perform_agree_profile_flag(_performed_by, _args)
    resolve_flag(:approved)
  end

  def perform_remove_profile_content(performed_by, _args)
    # Flag submission locks the profile before the reviewable. Let a concurrent report finish first.
    profile = target.lock!("FOR UPDATE NOWAIT")
    owner = profile.user.lock!("FOR UPDATE NOWAIT")
    performed_by.guardian.ensure_can_remove_profile_content!(owner)

    # Profile text belongs to the profile created at signup and has no separate timestamp.
    profile_date = owner.created_at if profile.bio_raw.present? || profile.website.present?
    field_date = owner.clear_public_profile_fields!
    removed_content = {
      "CONTENT_TYPE_TEXT" => [profile_date, field_date].compact.max,
      "CONTENT_TYPE_IMAGE" => [
        owner.uploaded_avatar&.created_at,
        profile.profile_background_upload&.created_at,
        profile.card_background_upload&.created_at,
      ].compact.max,
    }.compact
    if profile_date || profile.profile_background_upload_id? || profile.card_background_upload_id?
      profile.clear_reported_content!
    end
    owner.remove_avatar!(performed_by) if owner.uploaded_avatar_id?

    if removed_content.present?
      reviewable_notes.create!(
        user: performed_by,
        content:
          I18n.t(
            "reviewables.actions.remove_profile_content.note",
            locale: SiteSetting.default_locale,
          ),
      )
    end
    resolve_flag(:approved).tap { |result| result.removed_profile_content = removed_content }
  rescue ActiveRecord::LockWaitTimeout
    raise Reviewable::UpdateConflict
  end

  def perform_silence_user(performed_by, args)
    result = silence_user(performed_by:, args:)
    result.success? ? resolve_flag(:approved) : result
  end

  def perform_suspend_user(performed_by, args)
    result = suspend_user(performed_by:, args:)
    result.success? ? resolve_flag(:approved) : result
  end

  def perform_dismiss_profile_flag(_performed_by, _args)
    resolve_flag(:rejected)
  end

  def perform_ignore(_performed_by, _args)
    resolve_flag(:ignored)
  end

  private

  def clear_mention_titles!
    # A mention can outlive both its note and its recipient's staff role.
    mentions =
      Notification.where(notification_type: Notification.types[:mentioned], topic_id: nil).where(
        "data::jsonb ->> 'reviewable_id' = ?",
        id.to_s,
      )
    recipients = User.where(id: mentions.select(:user_id)).select(:id, :locale)
    recipients
      .group_by(&:effective_locale)
      .each_value do |users|
        title = title_for_notification(users.first)
        mentions
          .where(user_id: users.map(&:id))
          .where("data::jsonb ->> 'topic_title' IS DISTINCT FROM ?", title)
          .update_all(
            ["data = jsonb_set(data::jsonb, '{topic_title}', to_jsonb(?::text))::text", title],
          )
      end
  end

  def dsa_statement_attributes(action_id:, result:, automated_detection:, automated_decision:)
    if action_id == :remove_profile_content
      return if result.removed_profile_content.blank?

      return(
        {
          decision_facts: "Public content was removed from the reported user profile.",
          decision_visibility: ["DECISION_VISIBILITY_CONTENT_REMOVED"],
          content_type: result.removed_profile_content.keys,
          content_date: result.removed_profile_content.values.max.to_date.iso8601,
          automated_detection:,
          automated_decision:,
        }
      )
    end
    account_penalty_statement_attributes(action_id:, automated_detection:, automated_decision:)
  end

  def public_field_snapshot(user)
    fields = UserField.where(show_on_profile: true).order(:position, :id).pluck(:id, :name)
    return if fields.empty?

    values = user.user_fields(fields.map(&:first))
    fields.filter_map do |id, name|
      value = values[id.to_s]
      { name:, value: Array.wrap(value).join(", ") } if value.present?
    end
  end

  def resolve_flag(status)
    create_result(:success, status) do |result|
      result.update_flag_stats = {
        status: map_reviewable_status_to_flag_status(status),
        user_ids: reviewable_scores.pending.pluck(:user_id),
        flagged_user_id: target_created_by_id,
      }
      result.recalculate_score = true
    end
  end
end

# == Schema Information
#
# Table name: reviewables
#
#  id                      :bigint           not null, primary key
#  force_review            :boolean          default(FALSE), not null
#  latest_score            :datetime
#  payload                 :json
#  potential_spam          :boolean          default(FALSE), not null
#  potentially_illegal     :boolean          default(FALSE)
#  reject_reason           :text
#  reviewable_by_moderator :boolean          default(FALSE), not null
#  score                   :float            default(0.0), not null
#  status                  :integer          default("pending"), not null
#  target_type             :string
#  type                    :string           not null
#  type_source             :string           default("unknown"), not null
#  version                 :integer          default(0), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  category_id             :integer
#  created_by_id           :integer          not null
#  target_created_by_id    :integer
#  target_id               :integer
#  topic_id                :integer
#
# Indexes
#
#  idx_reviewables_score_desc_created_at_desc                  (score DESC,created_at DESC)
#  index_reviewables_on_reviewable_by_group_id                 (reviewable_by_group_id)
#  index_reviewables_on_status_and_created_at                  (status,created_at)
#  index_reviewables_on_status_and_score                       (status,score)
#  index_reviewables_on_status_and_type                        (status,type)
#  index_reviewables_on_target_created_by_id                   (target_created_by_id)
#  index_reviewables_on_target_id_where_post_type_eq_post      (target_id) WHERE ((target_type)::text = 'Post'::text)
#  index_reviewables_on_topic_id_and_status_and_created_by_id  (topic_id,status,created_by_id)
#  index_reviewables_on_type_and_target_id                     (type,target_id) UNIQUE
#
