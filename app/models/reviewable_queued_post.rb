# frozen_string_literal: true

class ReviewableQueuedPost < Reviewable
  include ReviewableActionBuilder

  def self.action_aliases
    { discard_post: :reject_post, delete_user_block: :delete_and_block_user }
  end

  after_create do
    # Backwards compatibility, new code should listen for `reviewable_created`
    DiscourseEvent.trigger(:queued_post_created, self)
  end

  after_save do
    if saved_change_to_payload? && status.to_sym == :pending && payload&.[]("raw").present?
      upload_ids = Upload.extract_upload_ids(payload["raw"])
      UploadReference.ensure_exist!(upload_ids: upload_ids, target: self)
    end
  end

  after_commit :compute_user_stats, only: %i[create update]

  def self.additional_args(params)
    args = ReviewableActionBuilder.penalty_args(params)
    return args if params[:revise_reason].blank?

    args.merge(
      revise_reason: params[:revise_reason],
      revise_feedback: params[:revise_feedback],
      revise_custom_reason: params[:revise_custom_reason],
    )
  end

  def build_combined_actions(actions, guardian, args)
    unless approved?
      if topic&.closed?
        build_action(actions, :approve_post_closed, icon: "check", confirm: true)
      else
        build_action(actions, :approve_post, icon: "check") if target_created_by.present?
      end
    end

    if pending?
      reject_bundle =
        actions.add_bundle(
          "#{id}-reject-post",
          label: "reviewables.actions.reject_post_bundle.title",
        )

      build_action(actions, :reject_post, bundle: reject_bundle, icon: "xmark")
      if target_created_by.present?
        build_action(actions, :revise_and_reject_post, bundle: reject_bundle, icon: "envelope")
      end

      build_penalty_actions(
        actions,
        bundle: reject_bundle,
        silence: :reject_and_silence,
        suspend: :reject_and_suspend,
      )

      delete_user_actions(actions, reject_bundle) if guardian.can_delete_user?(target_created_by)
    end

    build_action(actions, :delete) if guardian.can_delete?(self)
  end

  def build_editable_fields(fields, guardian, args)
    if pending?
      # We can edit category / title if it's a new topic
      if topic_id.blank?
        fields.add("payload.title", :text)

        # Only staff can edit category for now, since in theory a category group reviewer could
        # post in a category they don't have access to.
        fields.add("category_id", :category) if guardian.is_staff?

        fields.add("payload.tags", :tags)
      end

      fields.add("payload.raw", :editor)
    end
  end

  def create_options
    result = payload.symbolize_keys
    result[:cooking_options].symbolize_keys! if result[:cooking_options]
    result[:topic_id] = topic_id if topic_id
    result[:category] = category_id if category_id
    if result[:tags].present? && !result[:tags].is_a?(Array)
      raise Discourse::InvalidParameters.new(:tags)
    end
    if result[:tags].is_a?(Array)
      result[:tags] = result[:tags].map { |t| t.is_a?(Hash) ? t["name"] : t }
    end
    result
  end

  def perform_approve_post(performed_by, args)
    created_post = nil
    opts =
      create_options.merge(
        skip_validations: true,
        skip_jobs: true,
        skip_events: true,
        skip_guardian: true,
        reviewed_queued_post: true,
      )
    opts.merge!(guardian: Guardian.new(performed_by)) if performed_by.staff?

    creator = PostCreator.new(target_created_by, opts)
    created_post = creator.create

    unless created_post && creator.errors.blank?
      return create_result(:failure) { |r| r.errors = creator.errors }
    end

    self.target = created_post
    self.topic_id = created_post.topic_id if topic_id.nil?
    save

    if target_created_by.silenced?
      UserSilencer.unsilence(target_created_by, performed_by, reviewable_id: id)
    end

    if performed_by.staff?
      StaffActionLogger.new(performed_by).log_post_approved(created_post, reviewable_id: id)
    end

    # Backwards compatibility, new code should listen for `reviewable_transitioned_to`
    DiscourseEvent.trigger(:approved_post, self, created_post)

    Notification.create!(
      notification_type: Notification.types[:post_approved],
      user_id: target_created_by.id,
      data: { post_url: created_post.url }.to_json,
      topic_id: created_post.topic_id,
      post_number: created_post.post_number,
    )

    create_result(:success, :approved) do |result|
      result.created_post = created_post

      # Do sidekiq work outside of the transaction
      result.after_commit = -> do
        creator.enqueue_jobs
        creator.trigger_after_events
      end
    end
  end

  def perform_approve_post_closed(performed_by, args)
    perform_approve_post(performed_by, args)
  end

  def perform_reject_and_suspend(performed_by, args)
    result = suspend_user(performed_by:, args:)
    return result unless result.success?

    perform_reject_post(performed_by, args)
  end

  def perform_reject_and_silence(performed_by, args)
    result = silence_user(performed_by:, args:)
    return result unless result.success?

    perform_reject_post(performed_by, args)
  end

  def perform_reject_post(performed_by, args)
    # Backwards compatibility, new code should listen for `reviewable_transitioned_to`
    DiscourseEvent.trigger(:rejected_post, self)

    StaffActionLogger.new(performed_by).log_post_rejected(self, DateTime.now) if performed_by.staff?

    create_result(:success, :rejected)
  end

  def perform_revise_and_reject_post(performed_by, args)
    has_contact_user = SiteSetting.site_contact_username.present?
    is_new_topic = topic.blank?

    edit_instructions_key =
      if is_new_topic && has_contact_user
        "system_messages.reviewable_queued_post_revise_and_reject_edit_topic"
      elsif is_new_topic
        "system_messages.reviewable_queued_post_revise_and_reject_edit_topic_no_reply"
      elsif has_contact_user
        "system_messages.reviewable_queued_post_revise_and_reject_edit_post"
      else
        "system_messages.reviewable_queued_post_revise_and_reject_edit_post_no_reply"
      end

    pm_translation_args = {
      **Dsa::AppealInstructions.message_options,
      topic_title: topic&.title || payload["title"],
      topic_url: topic&.url,
      reason: args[:revise_custom_reason].presence || args[:revise_reason],
      feedback: args[:revise_feedback],
      original_post: payload["raw"],
      site_name: SiteSetting.title,
      edit_instructions: I18n.t(edit_instructions_key, locale: target_created_by.effective_locale),
    }

    SystemMessage.create(
      target_created_by,
      (
        if is_new_topic
          :reviewable_queued_post_revise_and_reject_new_topic
        else
          :reviewable_queued_post_revise_and_reject
        end
      ),
      pm_translation_args,
    )
    StaffActionLogger.new(performed_by).log_post_rejected(self, DateTime.now) if performed_by.staff?
    create_result(:success, :rejected)
  end

  def perform_delete(performed_by, args)
    create_result(:success, :deleted)
  end

  def perform_delete_user(performed_by, args)
    user = target_created_by
    reviewable_ids = Reviewable.where(created_by: user).pluck(:id)

    result =
      super do |result|
        result.deleted_user = user
        result.remove_reviewable_ids += reviewable_ids
      end

    update_column(:target_created_by_id, nil)
    result
  end

  def perform_delete_and_block_user(performed_by, args)
    user = target_created_by
    reviewable_ids = Reviewable.where(created_by: user).pluck(:id)

    result =
      super do |result|
        result.deleted_user = user
        result.remove_reviewable_ids += reviewable_ids
      end

    update_column(:target_created_by_id, nil)
    result
  end

  private

  def dsa_statement_attributes(action_id:, result:, automated_detection:, automated_decision:)
    case action_id
    when :reject_post, :revise_and_reject_post, :discard_post
      {
        decision_facts: "The post was held for approval and rejected before publication.",
        decision_visibility: ["DECISION_VISIBILITY_CONTENT_DISABLED"],
        content_type: ["CONTENT_TYPE_TEXT"],
        content_date: created_at.to_date.iso8601,
        automated_detection:,
        automated_decision:,
      }
    when :reject_and_suspend
      user = target_created_by.reload

      {
        decision_facts: "The author of a post held for approval was suspended.",
        decision_account: "DECISION_ACCOUNT_SUSPENDED",
        content_type: ["CONTENT_TYPE_OTHER"],
        content_type_other: "User account",
        content_date: user.created_at.to_date.iso8601,
        end_date_account_restriction:
          (user.suspended_till.to_date.iso8601 unless user.suspended_forever?),
        automated_detection:,
        automated_decision:,
      }.compact
    when :reject_and_silence
      user = target_created_by.reload

      {
        decision_facts:
          "The author of a post held for approval had their ability to participate restricted.",
        decision_provision: "DECISION_PROVISION_PARTIAL_SUSPENSION",
        content_type: ["CONTENT_TYPE_OTHER"],
        content_type_other: "User account",
        content_date: user.created_at.to_date.iso8601,
        end_date_service_restriction:
          (user.silenced_till.to_date.iso8601 unless user.silenced_forever?),
        automated_detection:,
        automated_decision:,
      }.compact
    when :delete_user, :delete_and_block_user, :delete_user_block
      user = result.deleted_user

      {
        decision_facts: "The author of a post held for approval had their account deleted.",
        decision_account: "DECISION_ACCOUNT_TERMINATED",
        content_type: ["CONTENT_TYPE_OTHER"],
        content_type_other: "User account",
        content_date: user.created_at.to_date.iso8601,
        automated_detection:,
        automated_decision:,
      }
    end
  end

  def delete_opts
    {
      context: I18n.t("reviewables.actions.delete_user.reason"),
      delete_posts: true,
      block_urls: true,
      delete_as_spammer: true,
    }
  end

  def compute_user_stats
    return unless status_changed_from_or_to_pending?
    target_created_by&.user_stat&.update_pending_posts
  end

  def status_changed_from_or_to_pending?
    saved_change_to_id?(from: nil) && pending? || saved_change_to_status?(from: "pending")
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
