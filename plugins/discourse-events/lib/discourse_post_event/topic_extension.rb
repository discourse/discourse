# frozen_string_literal: true

module DiscoursePostEvent
  module TopicExtension
    def move_posts(moved_by, post_ids, opts)
      ensure_event_invariants!(post_ids, opts)
      super
    end

    private

    def ensure_event_invariants!(post_ids, opts)
      return unless SiteSetting.discourse_post_event_enabled
      return unless opts[:destination_topic_id]

      destination = Topic.find_by(id: opts[:destination_topic_id])
      return unless destination

      destination_op = destination.first_post
      destination_has_event = destination_op&.event.present?
      incoming_event_post = Post.where(id: post_ids).joins(:event).order(:created_at).first

      return unless destination_has_event || incoming_event_post

      raise_event_move_error! if destination_has_event && incoming_event_post

      chronological = !!opts[:chronological_order]

      if destination_has_event && chronological
        oldest_incoming = Post.where(id: post_ids).order(:created_at).first
        if oldest_incoming && oldest_incoming.created_at < destination_op.created_at
          raise_event_move_error!
        end
      end

      if incoming_event_post && !destination_has_event
        becomes_new_op =
          chronological &&
            (destination_op.nil? || incoming_event_post.created_at < destination_op.created_at)
        raise_event_move_error! unless becomes_new_op
      end
    end

    def raise_event_move_error!
      raise ActiveRecord::RecordNotSaved.new(
              I18n.t("discourse_post_event.errors.models.event.must_be_in_first_post"),
            )
    end
  end
end
