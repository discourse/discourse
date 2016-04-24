class QueuedPost < ActiveRecord::Base

  class InvalidStateTransition < StandardError; end;

  belongs_to :user
  belongs_to :topic
  belongs_to :approved_by, class_name: "User"
  belongs_to :rejected_by, class_name: "User"

  has_one :queued_preview_post_map, foreign_key: :queued_id
  scope :with_queued_preview_map, -> { eager_load(:queued_preview_post_map) }

  def create_pending_action
    UserAction.log_action!(action_type: UserAction::PENDING,
                           user_id: user_id,
                           acting_user_id: user_id,
                           target_topic_id: topic_id,
                           queued_post_id: id)
  end

  def self.states
    @states ||= Enum.new(:new, :approved, :rejected)
  end

  # By default queues are hidden from moderators
  def self.visible_queues
    @visible_queues ||= Set.new(['default'])
  end

  def self.visible
    where(queue: visible_queues.to_a)
  end

  def self.new_posts
    where(state: states[:new])
  end

  def self.new_count
    new_posts.visible.count
  end

  def visible?
    QueuedPost.visible_queues.include?(queue)
  end

  def self.broadcast_new!
    msg = { post_queue_new_count: QueuedPost.new_count }
    MessageBus.publish('/queue_counts', msg, user_ids: User.staff.pluck(:id))
  end

  # Delete queued_preview post and topic if any
  def destroy_queued_preview!
    queued_preview_post_map.post.destroy if queued_preview_post_map.present? && queued_preview_post_map.post_id.present?
    queued_preview_post_map.topic.destroy if queued_preview_post_map.present? && queued_preview_post_map.topic_id.present?
  end

  def cleanup_hideing!
    queued_preview_post_map.destroy
  end

  def edit_queued_preview!(raw)
    if queued_preview_post_map.present? && queued_preview_post_map.post_id.present?
      post = Post.find(queued_preview_post_map.post_id)
      post.update_column(:raw, raw)
      post.rebake!
    end
  end

  def reject!(rejected_by)
    QueuedPost.transaction do
      change_to!(:rejected, rejected_by)
      if NewPostManager.queued_preview_enabled?
        destroy_queued_preview!
        cleanup_hideing!
      end
    end

    DiscourseEvent.trigger(:rejected_post, self)
  end

  def create_options
    opts = {raw: raw}
    opts.merge!(post_options.symbolize_keys)

    opts[:cooking_options].symbolize_keys! if opts[:cooking_options]
    opts[:topic_id] = topic_id if topic_id
    opts
  end

  def approve!(approved_by)
    created_post = nil
    QueuedPost.transaction do
      change_to!(:approved, approved_by)

      UserBlocker.unblock(user, approved_by) if user.blocked?

      unless NewPostManager.queued_preview_enabled?
        creator = PostCreator.new(user, create_options.merge(skip_validations: true, queued_preview_approving: true))
        created_post = creator.create
        unless created_post && creator.errors.blank?
          raise StandardError, "Failed to create post #{raw[0..100]} #{creator.errors.full_messages.inspect}"
        end
      end
    end

    if NewPostManager.queued_preview_enabled? && queued_preview_post_map.present? && queued_preview_post_map.post_id.present?
      post = queued_preview_post_map.post
      if post.present?
        new_topic = queued_preview_post_map.new_topic?
        cleanup_hideing!

        # Reapply events and jobs
        PostJobsEnqueuer.new(post, post.topic, new_topic, {queued_preview_approving: true}).enqueue_jobs
        opts = create_options
        DiscourseEvent.trigger(:topic_created, post.topic, opts, user) if new_topic
        DiscourseEvent.trigger(:post_created, post, opts, user)
        BadgeGranter.queue_badge_grant(Badge::Trigger::PostRevision, post: post)
        post.publish_change_to_clients! :created
        user.publish_notifications_state
      end
    end

    DiscourseEvent.trigger(:approved_post, self)

    if NewPostManager.queued_preview_enabled?
      post
    else
      created_post
    end
  end

  def edit_content!(raw)
    QueuedPost.transaction do
      update_column(:raw, raw)
      edit_queued_preview!(raw) if NewPostManager.queued_preview_enabled?
    end
  end

  private

    def change_to!(state, changed_by)
      state_val = QueuedPost.states[state]

      updates = { state: state_val,
                  "#{state}_by_id" => changed_by.id,
                  "#{state}_at" => Time.now }

      # We use an update with `row_count` trick here to avoid stampeding requests to
      # update the same row simultaneously. Only one state change should go through and
      # we can use the DB to enforce this
      row_count = QueuedPost.where('id = ? AND state <> ?', id, state_val).update_all(updates)
      raise InvalidStateTransition.new if row_count == 0

      if [:rejected, :approved].include?(state)
        UserAction.where(queued_post_id: id).destroy_all
      end

      # Update the record in memory too, and clear the dirty flag
      updates.each {|k, v| send("#{k}=", v) }
      changes_applied

      QueuedPost.broadcast_new! if visible?
    end

end

# == Schema Information
#
# Table name: queued_posts
#
#  id             :integer          not null, primary key
#  queue          :string           not null
#  state          :integer          not null
#  user_id        :integer          not null
#  raw            :text             not null
#  post_options   :json             not null
#  topic_id       :integer
#  approved_by_id :integer
#  approved_at    :datetime
#  rejected_by_id :integer
#  rejected_at    :datetime
#  created_at     :datetime
#  updated_at     :datetime
#
# Indexes
#
#  by_queue_status        (queue,state,created_at)
#  by_queue_status_topic  (topic_id,queue,state,created_at)
#
