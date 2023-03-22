# NOTE: When changing auto-join logic, make sure to update the `settings.auto_join_users_info` translation as well.
# frozen_string_literal: true

module Jobs
  module Chat
    class AutoJoinChannelMemberships < ::Jobs::Base
      def execute(args)
        channel =
          ::Chat::Channel.includes(:chatable).find_by(
            id: args[:chat_channel_id],
            auto_join_users: true,
            chatable_type: "Category",
          )

        return if !channel&.chatable

        processed =
          ::Chat::UserChatChannelMembership.where(
            chat_channel: channel,
            following: true,
            join_mode: ::Chat::UserChatChannelMembership.join_modes[:automatic],
          ).count

        auto_join_query(channel).find_in_batches do |batch|
          break if processed >= ::SiteSetting.max_chat_auto_joined_users

          starts_at = batch.first.query_user_id
          ends_at = batch.last.query_user_id

          ::Jobs.enqueue(
            ::Jobs::Chat::AutoJoinChannelBatch,
            chat_channel_id: channel.id,
            starts_at: starts_at,
            ends_at: ends_at,
          )

          processed += batch.size
        end

        # The Jobs::Chat::AutoJoinChannelBatch job will only do this recalculation
        # if it's operating on one user, so we need to make sure we do it for
        # the channel here once this job is complete.
        ::Chat::ChannelMembershipManager.new(channel).recalculate_user_count
      end

      private

      def auto_join_query(channel)
        category = channel.chatable

        users =
          ::User
            .real
            .activated
            .not_suspended
            .not_staged
            .distinct
            .select(:id, "users.id AS query_user_id")
            .where("last_seen_at > ?", 3.months.ago)
            .joins(:user_option)
            .where(user_options: { chat_enabled: true })
            .joins(<<~SQL)
            LEFT OUTER JOIN user_chat_channel_memberships uccm
            ON uccm.chat_channel_id = #{channel.id} AND
            uccm.user_id = users.id
          SQL
            .where("uccm.id IS NULL")

        if category.read_restricted?
          users =
            users
              .joins(:group_users)
              .joins("INNER JOIN category_groups cg ON cg.group_id = group_users.group_id")
              .where("cg.category_id = ?", channel.chatable_id)
        end

        users
      end
    end
  end
end
