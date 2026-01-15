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
    if saved_change_to_payload? && self.status.to_sym == :pending &&
         self.payload&.[]("raw").present?
      upload_ids = Upload.extract_upload_ids(self.payload["raw"])
      UploadReference.ensure_exist!(upload_ids: upload_ids, target: self)
    end
  end

  after_commit :compute_user_stats, only: %i[create update]

  def self.additional_args(params)
    return {} if params[:revise_reason].blank?

    {
      revise_reason: params[:revise_reason],
      revise_feedback: params[:revise_feedback],
      revise_custom_reason: params[:revise_custom_reason],
    }
  end

  def updatable_reviewable_scores
    # Approvals are possible for already rejected queued posts. We need the
    # scores to be updated when this happens.
    reviewable_scores.pending.or(reviewable_scores.disagreed)
  end

  # TODO (reviewable-refresh): Remove this method once new UI is fully deployed
  def build_legacy_combined_actions(actions, guardian, args)
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
      build_action(actions, :revise_and_reject_post, bundle: reject_bundle, icon: "envelope")

      delete_user_actions(actions, reject_bundle) if guardian.can_delete_user?(target_created_by)
    end

    build_action(actions, :delete) if guardian.can_delete?(self)
  end

  def build_new_separated_actions
    # Because a queued post isn't a real post, we need to create our own post actions bundle
    post_actions_bundle = build_post_actions_bundle

    unless approved?
      if topic&.closed?
        build_action(actions, :approve_post, bundle: post_actions_bundle, confirm: true)
      elsif target_created_by.present?
        build_action(actions, :approve_post, bundle: post_actions_bundle)
      end
    end

    if pending?
      build_action(actions, :reject_post, bundle: post_actions_bundle)
      build_action(actions, :revise_and_reject_post, bundle: post_actions_bundle)
    end

    # User actions bundle
    build_user_actions_bundle if pending?
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

    UserSilencer.unsilence(target_created_by, performed_by) if target_created_by.silenced?

    StaffActionLogger.new(performed_by).log_post_approved(created_post) if performed_by.staff?

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

  def perform_reject_post(performed_by, args)
    # Backwards compatibility, new code should listen for `reviewable_transitioned_to`
    DiscourseEvent.trigger(:rejected_post, self)

    StaffActionLogger.new(performed_by).log_post_rejected(self, DateTime.now) if performed_by.staff?

    create_result(:success, :rejected)
  end

  def perform_revise_and_reject_post(performed_by, args)
    pm_translation_args = {
      topic_title: self.topic&.title || self.payload["title"],
      topic_url: self.topic&.url,
      reason: args[:revise_custom_reason].presence || args[:revise_reason],
      feedback: args[:revise_feedback],
      original_post: self.payload["raw"],
      site_name: SiteSetting.title,
    }
    SystemMessage.create(
      self.target_created_by,
      (
        if self.topic.blank?
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
    reviewable_ids = Reviewable.where(created_by: target_created_by).pluck(:id)
    result = super { |r| r.remove_reviewable_ids += reviewable_ids }
    update_column(:target_created_by_id, nil)
    result
  end

  def perform_delete_and_block_user(performed_by, args)
    reviewable_ids = Reviewable.where(created_by: target_created_by).pluck(:id)
    result = super { |r| r.remove_reviewable_ids += reviewable_ids }
    update_column(:target_created_by_id, nil)
    result
  end

  private

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
#  type                    :string           not null
#  type_source             :string           default("unknown"), not null
#  status                  :integer          default("pending"), not null
#  created_by_id           :integer          not null
#  reviewable_by_moderator :boolean          default(FALSE), not null
#  category_id             :integer
#  topic_id                :integer
#  score                   :float            default(0.0), not null
#  potential_spam          :boolean          default(FALSE), not null
#  target_id               :integer
#  target_type             :string
#  target_created_by_id    :integer
#  payload                 :json
#  version                 :integer          default(0), not null
#  latest_score            :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  force_review            :boolean          default(FALSE), not null
#  reject_reason           :text
#  potentially_illegal     :boolean          default(FALSE)
#
# Indexes
#
#  idx_reviewables_score_desc_created_at_desc                  (score,created_at)
#  index_reviewables_on_reviewable_by_group_id                 (reviewable_by_group_id)
#  index_reviewables_on_status_and_created_at                  (status,created_at)
#  index_reviewables_on_status_and_score                       (status,score)
#  index_reviewables_on_status_and_type                        (status,type)
#  index_reviewables_on_target_id_where_post_type_eq_post      (target_id) WHERE ((target_type)::text = 'Post'::text)
#  index_reviewables_on_topic_id_and_status_and_created_by_id  (topic_id,status,created_by_id)
#  index_reviewables_on_type_and_target_id                     (type,target_id) UNIQUE
#
