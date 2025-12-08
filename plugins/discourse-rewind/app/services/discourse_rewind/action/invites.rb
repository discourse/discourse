# frozen_string_literal: true

# Invite statistics
# Shows how many users this user invited and the impact of those invitees
module DiscourseRewind
  module Action
    class Invites < BaseReport
      FakeData = {
        data: {
          total_invites: 18,
          redeemed_count: 12,
          redemption_rate: 66.7,
          invitee_post_count: 145,
          invitee_topic_count: 23,
          invitee_like_count: 89,
          avg_trust_level: 1.8,
          most_active_invitee: {
            id: 42,
            username: "newbie_123",
            name: "New User",
            avatar_template: "/letter_avatar_proxy/v4/letter/n/8c91d9/{size}.png",
          },
        },
        identifier: "invites",
      }

      def call
        return FakeData if should_use_fake_data?
        # Get all invites created by this user in the date range
        invites = Invite.where(invited_by_id: user.id).where(created_at: date)

        total_invites = invites.count
        return if total_invites == 0

        # Redeemed invites (users who actually joined)
        redeemed_count = invites.where("redemption_count > 0").count

        # Get the users who were invited (via InvitedUser or redeemed invites)
        invited_user_ids = InvitedUser.where(invite: invites).pluck(:user_id).compact

        invited_users = User.where(id: invited_user_ids)

        # Calculate impact of invitees
        invitee_post_count =
          Post.where(user_id: invited_user_ids).where(created_at: date).where(deleted_at: nil).count

        invitee_topic_count =
          Topic
            .where(user_id: invited_user_ids)
            .where(created_at: date)
            .where(deleted_at: nil)
            .count

        invitee_like_count =
          UserAction
            .where(user_id: invited_user_ids)
            .where(action_type: UserAction::LIKE)
            .where(created_at: date)
            .count

        # Calculate average trust level of invitees
        avg_trust_level = invited_users.average(:trust_level)&.to_f&.round(1) || 0

        # Most active invitee
        most_active_invitee = nil
        if invited_user_ids.any?
          most_active_id =
            Post
              .where(user_id: invited_user_ids)
              .where(created_at: date)
              .where(deleted_at: nil)
              .group(:user_id)
              .count
              .max_by { |_, count| count }
              &.first

          if most_active_id
            most_active_user = User.find_by(id: most_active_id)
            most_active_invitee =
              BasicUserSerializer.new(most_active_user, root: false).as_json if most_active_user
          end
        end

        {
          data: {
            total_invites: total_invites,
            redeemed_count: redeemed_count,
            redemption_rate:
              total_invites > 0 ? (redeemed_count.to_f / total_invites * 100).round(1) : 0,
            invitee_post_count: invitee_post_count,
            invitee_topic_count: invitee_topic_count,
            invitee_like_count: invitee_like_count,
            avg_trust_level: avg_trust_level,
            most_active_invitee: most_active_invitee,
          },
          identifier: "invites",
        }
      end
    end
  end
end
