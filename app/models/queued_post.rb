class QueuedPost < ActiveRecord::Base

  class InvalidStateTransition < StandardError; end

  belongs_to :user
  belongs_to :topic
  belongs_to :approved_by, class_name: "User"
  belongs_to :rejected_by, class_name: "User"

  after_commit :trigger_queued_post_event, on: :create

  def create_pending_action
    UserAction.log_action!(action_type: UserAction::PENDING,
                           user_id: user_id,
                           acting_user_id: user_id,
                           target_topic_id: topic_id,
                           queued_post_id: id)
  end

  def trigger_queued_post_event
    DiscourseEvent.trigger(:queued_post_created, self)
    true
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

  def reject!(rejected_by)
    change_to!(:rejected, rejected_by)
    StaffActionLogger.new(rejected_by).log_post_rejected(self)
    DiscourseEvent.trigger(:rejected_post, self)
  end

  def create_options
    opts = { raw: raw }
    opts.merge!(post_options.symbolize_keys)

    opts[:cooking_options].symbolize_keys! if opts[:cooking_options]
    opts[:topic_id] = topic_id if topic_id
    opts
  end

  def approve!(approved_by)
    created_post = nil

    creator = PostCreator.new(user, create_options.merge(
      skip_validations: true,
      skip_jobs: true,
      skip_events: true
    ))

    QueuedPost.transaction do
      change_to!(:approved, approved_by)

      UserSilencer.unsilence(user, approved_by) if user.silenced?

      created_post = creator.create

      unless created_post && creator.errors.blank?
        raise StandardError.new(creator.errors.full_messages.join(" "))
      else
        # Log post approval
        StaffActionLogger.new(approved_by).log_post_approved(created_post)
      end
    end

    # Do sidekiq work outside of the transaction
    creator.enqueue_jobs
    creator.trigger_after_events

    DiscourseEvent.trigger(:approved_post, self, created_post)
    created_post
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
    updates.each { |k, v| send("#{k}=", v) }
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
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  by_queue_status        (queue,state,created_at)
#  by_queue_status_topic  (topic_id,queue,state,created_at)
#
