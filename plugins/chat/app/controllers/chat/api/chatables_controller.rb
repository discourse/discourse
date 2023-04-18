# frozen_string_literal: true

class Chat::Api::ChatablesController < Chat::ApiController
  def index
    params.require(:filter)
    filter = params[:filter].downcase

    memberships = Chat::ChannelMembershipManager.all_for_user(current_user)

    public_channels =
      Chat::ChannelFetcher.secured_public_channels(
        guardian,
        memberships,
        filter: filter,
        status: :open,
      )

    users = User.joins(:user_option).where.not(id: current_user.id)
    if !Chat.allowed_group_ids.include?(Group::AUTO_GROUPS[:everyone])
      users =
        users
          .joins(:groups)
          .where(groups: { id: Chat.allowed_group_ids })
          .or(users.joins(:groups).staff)
    end

    users = users.where(user_option: { chat_enabled: true })
    like_filter = "%#{filter}%"
    if SiteSetting.prioritize_username_in_ux || !SiteSetting.enable_names
      users = users.where("users.username_lower ILIKE ?", like_filter)
    else
      users =
        users.where(
          "LOWER(users.name) ILIKE ? OR users.username_lower ILIKE ?",
          like_filter,
          like_filter,
        )
    end

    users = users.limit(25).uniq

    direct_message_channels =
      if users.count > 0
        # FIXME: investigate the cost of this query
        Chat::Channel
          .includes(chatable: :users)
          .joins(direct_message: :direct_message_users)
          .group(1)
          .having(
            "ARRAY[?] <@ ARRAY_AGG(user_id) AND ARRAY[?] && ARRAY_AGG(user_id)",
            [current_user.id],
            users.map(&:id),
          )
      else
        []
      end

    user_ids_with_channel = []
    direct_message_channels.each do |dm_channel|
      user_ids = dm_channel.chatable.users.map(&:id)
      user_ids_with_channel.concat(user_ids) if user_ids.count < 3
    end

    users_without_channel = users.filter { |u| !user_ids_with_channel.include?(u.id) }

    if current_user.username.downcase.start_with?(filter)
      # We filtered out the current user for the query earlier, but check to see
      # if they should be included, and add.
      users_without_channel << current_user
    end

    render_serialized(
      {
        public_channels: public_channels,
        direct_message_channels: direct_message_channels,
        users: users_without_channel,
        memberships: memberships,
      },
      Chat::ChannelSearchSerializer,
      root: false,
    )
  end
end
