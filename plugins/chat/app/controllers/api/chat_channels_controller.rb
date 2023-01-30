# frozen_string_literal: true

CHANNEL_EDITABLE_PARAMS = %i[name description slug]
CATEGORY_CHANNEL_EDITABLE_PARAMS = %i[auto_join_users allow_channel_wide_mentions]

class Chat::Api::ChatChannelsController < Chat::Api
  def index
    permitted = params.permit(:filter, :limit, :offset, :status)

    options = { filter: permitted[:filter], limit: (permitted[:limit] || 25).to_i }
    options[:offset] = permitted[:offset].to_i
    options[:status] = ChatChannel.statuses[permitted[:status]] ? permitted[:status] : nil

    memberships = Chat::ChatChannelMembershipManager.all_for_user(current_user)
    channels = Chat::ChatChannelFetcher.secured_public_channels(guardian, memberships, options)
    serialized_channels =
      channels.map do |channel|
        ChatChannelSerializer.new(
          channel,
          scope: Guardian.new(current_user),
          membership: memberships.find { |membership| membership.chat_channel_id == channel.id },
        )
      end

    load_more_params = options.merge(offset: options[:offset] + options[:limit]).to_query
    load_more_url = URI::HTTP.build(path: "/chat/api/channels", query: load_more_params).request_uri

    render json: serialized_channels, root: "channels", meta: { load_more_url: load_more_url }
  end

  def destroy
    confirmation = params.require(:channel).require(:name_confirmation)&.downcase
    guardian.ensure_can_delete_chat_channel!

    if channel_from_params.title(current_user).downcase != confirmation
      raise Discourse::InvalidParameters.new(:name_confirmation)
    end

    begin
      ChatChannel.transaction do
        channel_from_params.update!(
          slug:
            "#{Time.now.strftime("%Y%m%d-%H%M")}-#{channel_from_params.slug}-deleted".truncate(
              SiteSetting.max_topic_title_length,
              omission: "",
            ),
        )
        channel_from_params.trash!(current_user)
        StaffActionLogger.new(current_user).log_custom(
          "chat_channel_delete",
          {
            chat_channel_id: channel_from_params.id,
            chat_channel_name: channel_from_params.title(current_user),
          },
        )
      end
    rescue ActiveRecord::Rollback
      return render_json_error(I18n.t("chat.errors.delete_channel_failed"))
    end

    Jobs.enqueue(:chat_channel_delete, { chat_channel_id: channel_from_params.id })
    render json: success_json
  end

  def create
    channel_params =
      params.require(:channel).permit(:chatable_id, :name, :slug, :description, :auto_join_users)

    guardian.ensure_can_create_chat_channel!
    if channel_params[:name].length > SiteSetting.max_topic_title_length
      raise Discourse::InvalidParameters.new(:name)
    end

    if ChatChannel.exists?(
         chatable_type: "Category",
         chatable_id: channel_params[:chatable_id],
         name: channel_params[:name],
       )
      raise Discourse::InvalidParameters.new(I18n.t("chat.errors.channel_exists_for_category"))
    end

    chatable = Category.find_by(id: channel_params[:chatable_id])
    raise Discourse::NotFound unless chatable

    auto_join_users =
      ActiveRecord::Type::Boolean.new.deserialize(channel_params[:auto_join_users]) || false

    channel =
      chatable.create_chat_channel!(
        name: channel_params[:name],
        slug: channel_params[:slug],
        description: channel_params[:description],
        user_count: 1,
        auto_join_users: auto_join_users,
      )

    channel.user_chat_channel_memberships.create!(user: current_user, following: true)

    if channel.auto_join_users
      Chat::ChatChannelMembershipManager.new(channel).enforce_automatic_channel_memberships
    end

    render_serialized(
      channel,
      ChatChannelSerializer,
      membership: channel.membership_for(current_user),
      root: "channel",
    )
  end

  def show
    render_serialized(
      channel_from_params,
      ChatChannelSerializer,
      membership: channel_from_params.membership_for(current_user),
      root: "channel",
    )
  end

  def update
    guardian.ensure_can_edit_chat_channel!

    if channel_from_params.direct_message_channel?
      raise Discourse::InvalidParameters.new(
              I18n.t("chat.errors.cant_update_direct_message_channel"),
            )
    end

    params_to_edit = editable_params(params, channel_from_params)
    params_to_edit.each { |k, v| params_to_edit[k] = nil if params_to_edit[k].blank? }

    if ActiveRecord::Type::Boolean.new.deserialize(params_to_edit[:auto_join_users])
      auto_join_limiter(channel_from_params).performed!
    end

    channel_from_params.update!(params_to_edit)

    ChatPublisher.publish_chat_channel_edit(channel_from_params, current_user)

    if channel_from_params.category_channel? && channel_from_params.auto_join_users
      Chat::ChatChannelMembershipManager.new(
        channel_from_params,
      ).enforce_automatic_channel_memberships
    end

    render_serialized(
      channel_from_params,
      ChatChannelSerializer,
      root: "channel",
      membership: channel_from_params.membership_for(current_user),
    )
  end

  private

  def channel_from_params
    @channel ||=
      begin
        channel = ChatChannel.find(params.require(:channel_id))
        guardian.ensure_can_preview_chat_channel!(channel)
        channel
      end
  end

  def membership_from_params
    @membership ||=
      begin
        membership =
          Chat::ChatChannelMembershipManager.new(channel_from_params).find_for_user(current_user)
        raise Discourse::NotFound if membership.blank?
        membership
      end
  end

  def auto_join_limiter(channel)
    RateLimiter.new(
      current_user,
      "auto_join_users_channel_#{channel.id}",
      1,
      3.minutes,
      apply_limit_to_staff: true,
    )
  end

  def editable_params(params, channel)
    permitted_params = CHANNEL_EDITABLE_PARAMS
    permitted_params += CATEGORY_CHANNEL_EDITABLE_PARAMS if channel.category_channel?
    params.require(:channel).permit(*permitted_params)
  end
end
