# frozen_string_literal: true

module DiscourseRewind
  module Action
    class Invites < BaseReport
      MINIMUM_INVITES = 2
      MINIMUM_REDEEMED = 1
      MINIMUM_INVITEE_POSTS = 5

      FakeData = {
        data: {
          total_invites: 18,
          redeemed_count: 12,
          redemption_rate: 66.7,
          invitee_post_count: 145,
          invitee_topic_count: 23,
          invitee_like_count: 89,
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

        invites = Invite.where(invited_by_id: user.id, created_at: date)
        total_invites, redeemed_count =
          invites.pick(
            Arel.sql("COUNT(*)"),
            Arel.sql("COUNT(*) FILTER (WHERE redemption_count > 0)"),
          )

        return if total_invites < MINIMUM_INVITES || redeemed_count < MINIMUM_REDEEMED

        invitee_ids = InvitedUser.where(invite: invites).select(:user_id)
        post_counts = Post.where(user_id: invitee_ids, created_at: date).group(:user_id).count
        invitee_post_count = post_counts.values.sum

        return if invitee_post_count < MINIMUM_INVITEE_POSTS

        most_active_invitee = User.find(post_counts.max_by(&:last).first)

        {
          data: {
            total_invites:,
            redeemed_count:,
            redemption_rate: (redeemed_count.to_f / total_invites * 100).round(1),
            invitee_post_count:,
            invitee_topic_count: Topic.where(user_id: invitee_ids, created_at: date).count,
            invitee_like_count:
              UserAction.where(
                user_id: invitee_ids,
                action_type: UserAction::LIKE,
                created_at: date,
              ).count,
            most_active_invitee: BasicUserSerializer.new(most_active_invitee, root: false).as_json,
          },
          identifier: "invites",
        }
      end

      def self.filter_for_viewer(report, guardian:, for_user:)
        report if guardian.can_see_invite_details?(for_user)
      end
    end
  end
end
