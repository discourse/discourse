# frozen_string_literal: true

module DiscourseEvents
  module Events
    class EventCardSerializer < BasicEventSerializer
      attributes :creator, :description, :location, :url, :sample_invitees

      has_one :image_upload, embed: :object, serializer: UploadSerializer

      def self.sample_invitees_by_event(events)
        event_ids = events.map(&:id)
        return {} if event_ids.empty?

        limit = SiteSetting.displayed_invitees_limit
        ranked_invitees =
          Invitee
            .unscoped
            .joins(:user)
            .merge(User.not_suspended)
            .merge(User.not_silenced)
            .merge(User.not_staged)
            .where.not(users: { id: nil })
            .where(post_id: event_ids)
            .select(
              "discourse_post_event_invitees.*, " \
                "ROW_NUMBER() OVER (" \
                "PARTITION BY discourse_post_event_invitees.post_id " \
                "ORDER BY discourse_post_event_invitees.status, " \
                "discourse_post_event_invitees.created_at, " \
                "discourse_post_event_invitees.user_id" \
                ") AS rank",
            )

        Invitee
          .from("(#{ranked_invitees.to_sql}) discourse_post_event_invitees")
          .where("rank <= ?", limit)
          .preload(:user)
          .group_by(&:post_id)
      end

      def creator
        BasicUserSerializer.new(object.post.user, scope:, root: false).as_json
      end

      def sample_invitees
        ActiveModel::ArraySerializer.new(
          @options.fetch(:sample_invitees_by_event, {})[object.id] || object.most_likely_going,
          each_serializer: InviteeSerializer,
          scope:,
        ).as_json
      end

      def include_sample_invitees?
        scope.can_display_invitee_details?(object)
      end
    end
  end
end
