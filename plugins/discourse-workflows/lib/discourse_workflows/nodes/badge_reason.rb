# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    # Badge 1.0 and Grant badge link a grant to a post like the reason on the admin badge page, which also
    # takes a prefixed ID here.
    module BadgeReason
      PREFIXED_ID = /\A(?:(post|topic):)?([0-9]+)\z/

      def self.property(display_options: {})
        {
          type: :string,
          required: false,
          ui: {
            description_key: "admin.badges.reason_help",
          },
          display_options: {
            **display_options,
            hide: {
              badge_id: [
                { condition: { metadata_flag: { collection: "badges", flag: "hide_reason" } } },
              ],
            },
          },
        }
      end

      def self.hidden?(badge)
        badge.system? && !badge.show_posts?
      end

      def self.find_post(reason, guardian:)
        reason = reason.to_s.strip
        reference = PREFIXED_ID.match(reason)
        return BadgeGranter.post_for_reason(reason, guardian:) if !reference

        type, id = reference.captures
        if !type
          raise NodeError, I18n.t("discourse_workflows.errors.badge.reason_id_requires_prefix", id:)
        end

        post = type == "post" ? ::Post.find_by(id:) : ::Post.find_by(topic_id: id, post_number: 1)
        if !post
          raise NodeError,
                I18n.t("discourse_workflows.errors.badge.reason_id_not_found", reference: reason)
        end

        guardian.ensure_can_see!(post)
        post
      rescue BadgeGranter::InvalidReason => error
        raise NodeError, error.message
      end
    end
  end
end
