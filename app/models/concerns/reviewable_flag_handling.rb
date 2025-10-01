# frozen_string_literal: true

module ReviewableFlagHandling
  extend ActiveSupport::Concern

  protected

  # Returns the PostActionTypeView for flag operations.
  #
  # @return [PostActionTypeView] The post action type view instance.
  def post_action_type_view
    @post_action_type_view ||= PostActionTypeView.new
  end

  # Agree with flags on the target post. Updates PostAction records to mark them as agreed,
  # adds moderator posts, triggers events, and optionally executes a block with the first action.
  #
  # @param performed_by [User] The user performing the action.
  # @param args [Hash] Additional arguments for the action.
  # @yield [PostAction] Optional block to execute with the first flag action (e.g., hide post).
  #
  # @return [Array<Integer>] Array of user IDs who flagged the post.
  def agree_with_flags(performed_by, args)
    actions =
      PostAction
        .active
        .where(post_id: target_post.id)
        .where(post_action_type_id: post_action_type_view.notify_flag_types.values)

    trigger_spam = false
    actions.each do |action|
      ActiveRecord::Base.transaction do
        action.agreed_at = Time.zone.now
        action.agreed_by_id = performed_by.id
        # so callback is called
        action.save
        DB.after_commit do
          action.add_moderator_post_if_needed(performed_by, :agreed, args[:post_was_deleted])
          trigger_spam = true if action.post_action_type_id == post_action_type_view.types[:spam]
        end
      end
    end

    DiscourseEvent.trigger(:confirmed_spam_post, target_post) if trigger_spam

    if actions.first.present?
      DiscourseEvent.trigger(:flag_reviewed, target_post)
      DiscourseEvent.trigger(:flag_agreed, actions.first)
      yield(actions.first) if block_given?
    end

    actions.map(&:user_id)
  end

  # Disagree with flags on the target post. Updates PostAction records to mark them as disagreed,
  # resets flag counters, unhides the post if needed, and triggers events.
  #
  # @param performed_by [User] The user performing the action.
  # @param args [Hash] Additional arguments for the action.
  # @yield [PostAction] Optional block to execute with the first flag action.
  #
  # @return [Array<Integer>] Array of user IDs who flagged the post.
  def disagree_with_flags(performed_by, args)
    # -1 is the automatic system clear
    action_type_ids =
      if performed_by.id == Discourse::SYSTEM_USER_ID
        post_action_type_view.auto_action_flag_types.values
      else
        post_action_type_view.notify_flag_type_ids
      end

    actions =
      PostAction.active.where(post_id: target_post.id).where(post_action_type_id: action_type_ids)

    actions.each do |action|
      action.disagreed_at = Time.zone.now
      action.disagreed_by_id = performed_by.id
      # so callback is called
      action.save
      action.add_moderator_post_if_needed(performed_by, :disagreed)
    end

    # reset all cached counters
    cached = {}
    action_type_ids.each do |atid|
      column = "#{post_action_type_view.types[atid]}_count"
      cached[column] = 0 if ActiveRecord::Base.connection.column_exists?(:posts, column)
    end

    Post.with_deleted.where(id: target_post.id).update_all(cached)

    if actions.first.present?
      DiscourseEvent.trigger(:flag_reviewed, target_post)
      DiscourseEvent.trigger(:flag_disagreed, actions.first)
      yield(actions.first) if block_given?
    end

    # Undo hide/silence if applicable
    if target_post&.hidden?
      target_post.unhide!
      UserSilencer.unsilence(target_post.user) if UserSilencer.was_silenced_for?(target_post)
    end

    actions.map(&:user_id)
  end

  # Ignore flags on the target post. Updates PostAction records to mark them as deferred
  # and triggers events.
  #
  # @param performed_by [User] The user performing the action.
  # @param args [Hash] Additional arguments for the action.
  # @yield [PostAction] Optional block to execute with the first flag action.
  #
  # @return [Array<Integer>] Array of user IDs who flagged the post.
  def ignore_flags(performed_by, args)
    actions =
      PostAction
        .active
        .where(post_id: target_post.id)
        .where(post_action_type_id: post_action_type_view.notify_flag_type_ids)

    actions.each do |action|
      action.deferred_at = Time.zone.now
      action.deferred_by_id = performed_by.id
      # so callback is called
      action.save
      unless args[:expired]
        action.add_moderator_post_if_needed(performed_by, :ignored, args[:post_was_deleted])
      end
    end

    if actions.first.present?
      DiscourseEvent.trigger(:flag_reviewed, target_post)
      DiscourseEvent.trigger(:flag_deferred, actions.first)
      yield(actions.first) if block_given?
    end

    actions.map(&:user_id)
  end
end
