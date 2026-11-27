# frozen_string_literal: true

module DiscourseAssign
  module TrackingPostVisibility
    ACTION_CODES = %w[
      assigned_to_post
      assigned_group_to_post
      unassigned_from_post
      unassigned_group_from_post
      note_change
      status_change
      details_change
    ].freeze

    def self.tracking_posts
      Post.with_deleted.where(
        action_code: ACTION_CODES,
        post_type: [Post.types[:small_action], Post.types[:whisper]],
      )
    end

    def self.reconcile_for(target)
      tracking_posts
        .where(
          id:
            PostCustomField.where(name: "action_code_post_id", value: target.id.to_s).select(
              :post_id,
            ),
        )
        .find_each { |tracking| reconcile(tracking, target) }

      # A tracking post can itself be moved or have its type changed.
      if ACTION_CODES.include?(target.action_code)
        target_id = target.custom_fields["action_code_post_id"]
        reconcile(target, Post.with_deleted.find_by(id: target_id)) if target_id
      end
    end

    def self.reconcile(tracking, target)
      # Neither the topic nor the whisper audience is guaranteed to be contained
      # in a hidden/deleted target's audience. Cross-topic links are unsafe too:
      # moving either post must not leave notes behind for the old audience.
      if !target || target.hidden? || target.trashed? || tracking.topic_id != target.topic_id
        tracking.destroy!
      elsif target.whisper? && !tracking.whisper?
        tracking.update!(post_type: Post.types[:whisper])
      end
      # Never widen a historical whisper, even when the target becomes public.
    end
  end
end
