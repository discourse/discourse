# frozen_string_literal: true

class Chat::Api::ChatablesController < Chat::ApiController
  def index
    filter = params[:filter].downcase

    users = filtered_users(filter: filter)
    dm_channels = direct_message_channels(users: users)

    if dm_channels.any?
      user_ids_with_channel = []
      dm_channels.each do |dm_channel|
        user_ids = dm_channel.chatable.users.map(&:id)
        user_ids_with_channel.concat(user_ids) if user_ids.count < 3
      end

      users_without_channel = users.filter { |u| !user_ids_with_channel.include?(u.id) }

      if current_user.username.downcase.start_with?(filter)
        # We filtered out the current user for the query earlier, but check to see
        # if they should be included, and add.
        users_without_channel << current_user
      end

      users = users_without_channel
    end

    users = [] if !included_chatable_types.include?("user")

    memberships = Chat::ChannelMembershipManager.all_for_user(current_user)

    render_serialized(
      {
        public_channels: public_channels(filter: filter, memberships: memberships),
        direct_message_channels: dm_channels,
        users: users,
        memberships: memberships,
      },
      Chat::ChannelSearchSerializer,
      root: false,
    )
  end

  private

  def limit
    params[:limit] || 25
  end

  def included_chatable_types
    return "user", "public_channel", "direct_message_channel" if params["chatable_types"].blank?

    params["chatable_types"]
  end

  def last_seen_users
    !!ActiveModel::Type::Boolean.new.cast(params[:last_seen_users])
  end

  def public_channels(filter:, memberships:)
    return [] if !included_chatable_types.include?("public_channel")

    Chat::ChannelFetcher.secured_public_channels(
      guardian,
      memberships,
      filter: filter,
      status: :open,
    )
  end

  def direct_message_channels(users:)
    return [] if !included_chatable_types.include?("direct_message_channel") || users.blank?

    # FIXME: investigate the cost of this query
    Chat::DirectMessageChannel
      .includes(chatable: :users)
      .joins(direct_message: :direct_message_users)
      .group(1)
      .having(
        "ARRAY[?] <@ ARRAY_AGG(user_id) AND ARRAY[?] && ARRAY_AGG(user_id)",
        [current_user.id],
        users.map(&:id),
      )
  end

  def filtered_users(filter:)
    users = User.includes(:user_option, :groups).where.not(id: current_user.id)

    if params[:include_cannot_chat]
      filter_users_including_cannot_chat(filter: filter, users: users)
    else
      filter_users_can_chat(filter: filter, users: users)
    end
  end

  def filter_users_including_cannot_chat(filter:, users:)
    # We limit at the top and then loop over with Ruby to set `can_chat`
    users = filter_users_by_params(filter: filter, users: users).limit(limit).uniq

    chat_group_ids = Chat.allowed_group_ids
    everyone_can_chat = chat_group_ids.include?(Group::AUTO_GROUPS[:everyone])
    users.each do |user|
      user.can_chat =
        (everyone_can_chat || (user.group_ids & chat_group_ids).present? || user.staff?) &&
          user.user_option.chat_enabled
    end

    users
  end

  def filter_users_can_chat(filter:, users:)
    if !Chat.allowed_group_ids.include?(Group::AUTO_GROUPS[:everyone])
      users =
        users
          .joins(:groups)
          .where(groups: { id: Chat.allowed_group_ids })
          .or(users.joins(:groups).staff)
    end

    users = users.where(user_option: { chat_enabled: true })
    users =
      filter_users_by_params(filter: filter, users: users)
        .limit(limit)
        .uniq
        .each { |u| u.can_chat = true }

    users
  end

  def filter_users_by_params(filter:, users:)
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

    if params[:exclude].present?
      users = users.where("users.username_lower NOT IN (?)", params[:exclude])
    end

    users = users.order("last_seen_at DESC NULLS LAST") if last_seen_users

    users
  end
end
