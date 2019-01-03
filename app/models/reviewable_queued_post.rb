require_dependency 'reviewable'
require_dependency 'user_destroyer'

class ReviewableQueuedPost < Reviewable

  after_create do
    # Backwards compatibility, new code should listen for `reviewable_created`
    DiscourseEvent.trigger(:queued_post_created, self)
  end

  def build_actions(actions, guardian, args)
    return unless guardian.is_staff?

    actions.add(:approve) unless approved?
    actions.add(:reject) unless rejected?

    if pending? && guardian.can_delete_user?(created_by)
      actions.add(:delete_user) do |action|
        action.icon = 'trash-alt'
        action.label = 'reviewables.actions.delete_user.title'
        action.confirm_message = 'reviewables.actions.delete_user.confirm'
      end
    end
  end

  def build_editable_fields(fields, guardian, args)
    return unless guardian.is_staff?

    # We can edit category / title if it's a new topic
    if topic_id.blank?
      fields.add('category_id', :category)
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

  def perform_approve(performed_by, args)
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

    payload['created_post_id'] = created_post.id
    payload['created_topic_id'] = created_post.topic_id unless topic_id
    save

    UserSilencer.unsilence(created_by, performed_by) if created_by.silenced?

    StaffActionLogger.new(performed_by).log_post_approved(created_post) if performed_by.staff?

    # Backwards compatibility, new code should listen for `reviewable_transitioned_to`
    DiscourseEvent.trigger(:approved_post, self, created_post)

    create_result(:success, :approved) { |result| result.created_post = created_post }
  end

  def perform_reject(performed_by, args)
    # Backwards compatibility, new code should listen for `reviewable_transitioned_to`
    DiscourseEvent.trigger(:rejected_post, self)

    StaffActionLogger.new(performed_by).log_post_rejected(self, DateTime.now) if performed_by.staff?

    create_result(:success, :rejected)
  end

  def perform_delete_user(performed_by, args)
    delete_options = {
      context: I18n.t('reviewables.actions.delete_user.reason'),
      delete_posts: true,
      delete_as_spammer: true
    }

    if Rails.env.production?
      delete_options.merge!(block_email: true, block_ip: true)
    end

    reviewable_ids = Reviewable.where(created_by: created_by).pluck(:id)
    UserDestroyer.new(performed_by).destroy(created_by, delete_options)
    create_result(:success) { |r| r.remove_reviewable_ids = reviewable_ids }
  end

end

# == Schema Information
#
# Table name: reviewables
#
#  id                      :bigint(8)        not null, primary key
#  type                    :string           not null
#  status                  :integer          default(0), not null
#  created_by_id           :integer          not null
#  reviewable_by_moderator :boolean          default(FALSE), not null
#  reviewable_by_group_id  :integer
#  claimed_by_id           :integer
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
#
# Indexes
#
#  index_reviewables_on_status_and_created_at  (status,created_at)
#  index_reviewables_on_status_and_score       (status,score)
#  index_reviewables_on_status_and_type        (status,type)
#  index_reviewables_on_type_and_target_id     (type,target_id) UNIQUE
#
