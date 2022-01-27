# frozen_string_literal: true

class ReviewableQueuedPost < Reviewable

  after_create do
    # Backwards compatibility, new code should listen for `reviewable_created`
    DiscourseEvent.trigger(:queued_post_created, self)
  end

  after_commit :compute_user_stats, only: %i[create update]

  def build_actions(actions, guardian, args)

    unless approved?

      if topic&.closed?
        actions.add(:approve_post_closed) do |a|
          a.icon = 'check'
          a.label = "reviewables.actions.approve_post.title"
          a.confirm_message = "reviewables.actions.approve_post.confirm_closed"
        end
      else
        actions.add(:approve_post) do |a|
          a.icon = 'check'
          a.label = "reviewables.actions.approve_post.title"
        end
      end
    end

    unless rejected?
      actions.add(:reject_post) do |a|
        a.icon = 'times'
        a.label = "reviewables.actions.reject_post.title"
      end
    end

    if pending? && guardian.can_delete_user?(created_by)
      delete_user_actions(actions)
    end

    actions.add(:delete) if guardian.can_delete?(self)
  end

  def build_editable_fields(fields, guardian, args)

    # We can edit category / title if it's a new topic
    if topic_id.blank?

      # Only staff can edit category for now, since in theory a category group reviewer could
      # post in a category they don't have access to.
      fields.add('category_id', :category) if guardian.is_staff?

      fields.add('payload.title', :text)
      fields.add('payload.tags', :tags)
    end

    fields.add('payload.raw', :editor)
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

    creator = PostCreator.new(created_by, create_options.merge(
      skip_validations: true,
      skip_jobs: true,
      skip_events: true,
      skip_guardian: true
    ))
    created_post = creator.create

    unless created_post && creator.errors.blank?
      return create_result(:failure) { |r| r.errors = creator.errors }
    end

    self.target = created_post
    if topic_id.nil?
      self.topic_id = created_post.topic_id
    end
    save

    UserSilencer.unsilence(created_by, performed_by) if created_by.silenced?

    StaffActionLogger.new(performed_by).log_post_approved(created_post) if performed_by.staff?

    # Backwards compatibility, new code should listen for `reviewable_transitioned_to`
    DiscourseEvent.trigger(:approved_post, self, created_post)

    Notification.create!(
      notification_type: Notification.types[:post_approved],
      user_id: created_by.id,
      data: { post_url: created_post.url }.to_json,
      topic_id: created_post.topic_id,
      post_number: created_post.post_number
    )

    create_result(:success, :approved) do |result|
      result.created_post = created_post

      # Do sidekiq work outside of the transaction
      result.after_commit = -> {
        creator.enqueue_jobs
        creator.trigger_after_events
      }
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

  def perform_delete(performed_by, args)
    create_result(:success, :deleted)
  end

  def perform_delete_user(performed_by, args)
    delete_user(performed_by, delete_opts)
  end

  def perform_delete_user_block(performed_by, args)
    delete_options = delete_opts

    if Rails.env.production?
      delete_options.merge!(block_email: true, block_ip: true)
    end

    delete_user(performed_by, delete_options)
  end

  private

  def delete_user(performed_by, delete_options)
    reviewable_ids = Reviewable.where(created_by: created_by).pluck(:id)
    UserDestroyer.new(performed_by).destroy(created_by, delete_options)
    create_result(:success) { |r| r.remove_reviewable_ids = reviewable_ids }
  end

  def delete_opts
    {
      context: I18n.t('reviewables.actions.delete_user.reason'),
      delete_posts: true,
      block_urls: true,
      delete_as_spammer: true
    }
  end

  def compute_user_stats
    return unless status_changed_from_or_to_pending?
    created_by.user_stat.update_pending_posts
  end

  def status_changed_from_or_to_pending?
    saved_change_to_id?(from: nil) && pending? ||
      saved_change_to_status?(from: self.class.statuses[:pending])
  end
end

# == Schema Information
#
# Table name: reviewables
#
#  id                      :bigint           not null, primary key
#  type                    :string           not null
#  status                  :integer          default(0), not null
#  created_by_id           :integer          not null
#  reviewable_by_moderator :boolean          default(FALSE), not null
#  reviewable_by_group_id  :integer
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
#
# Indexes
#
#  index_reviewables_on_reviewable_by_group_id                 (reviewable_by_group_id)
#  index_reviewables_on_status_and_created_at                  (status,created_at)
#  index_reviewables_on_status_and_score                       (status,score)
#  index_reviewables_on_status_and_type                        (status,type)
#  index_reviewables_on_target_id_where_post_type_eq_post      (target_id) WHERE ((target_type)::text = 'Post'::text)
#  index_reviewables_on_topic_id_and_status_and_created_by_id  (topic_id,status,created_by_id)
#  index_reviewables_on_type_and_target_id                     (type,target_id) UNIQUE
#
