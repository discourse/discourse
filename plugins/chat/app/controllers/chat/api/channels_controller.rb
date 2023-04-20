# frozen_string_literal: true

CHANNEL_EDITABLE_PARAMS = %i[name description slug]
CATEGORY_CHANNEL_EDITABLE_PARAMS = %i[auto_join_users allow_channel_wide_mentions]

class Chat::Api::ChannelsController < Chat::ApiController
  def index
    permitted = params.permit(:filter, :limit, :offset, :status)

    options = { filter: permitted[:filter], limit: (permitted[:limit] || 25).to_i }
    options[:offset] = permitted[:offset].to_i
    options[:status] = Chat::Channel.statuses[permitted[:status]] ? permitted[:status] : nil

    memberships = Chat::ChannelMembershipManager.all_for_user(current_user)
    channels = Chat::ChannelFetcher.secured_public_channels(guardian, memberships, options)
    serialized_channels =
      channels.map do |channel|
        Chat::ChannelSerializer.new(
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
    with_service Chat::TrashChannel do
      on_model_not_found(:channel) { raise ActiveRecord::RecordNotFound }
    end
  end

  def create
    channel_params =
      params.require(:channel).permit(:chatable_id, :name, :slug, :description, :auto_join_users)

    # NOTE: We don't allow creating channels for anything but category chatable types
    # at the moment. This may change in future, at which point we will need to pass in
    # a chatable_type param as well and switch to the correct service here.
    with_service(
      Chat::CreateCategoryChannel,
      **channel_params.merge(category_id: channel_params[:chatable_id]),
    ) do
      on_success do
        render_serialized(
          result.channel,
          Chat::ChannelSerializer,
          root: "channel",
          membership: result.membership,
        )
      end
      on_model_not_found(:category) { raise ActiveRecord::RecordNotFound }
      on_failed_policy(:can_create_channel) { raise Discourse::InvalidAccess }
      on_failed_policy(:category_channel_does_not_exist) do
        raise Discourse::InvalidParameters.new(I18n.t("chat.errors.channel_exists_for_category"))
      end
      on_failed_step(:create_channel) do
        render(
          json: failed_json.merge(errors: result[:"result.step.create_channel"].errors),
          status: 400,
        )
      end
      on_failed_step(:create_membership) do
        render(
          json: failed_json.merge(errors: result[:"result.step.create_membership"].errors),
          status: 400,
        )
      end
    end
  end

  def show
    render_serialized(
      channel_from_params,
      Chat::ChannelSerializer,
      membership: channel_from_params.membership_for(current_user),
      root: "channel",
    )
  end

  def update
    params_to_edit = editable_params(params, channel_from_params)
    params_to_edit.each { |k, v| params_to_edit[k] = nil if params_to_edit[k].blank? }
    if ActiveRecord::Type::Boolean.new.deserialize(params_to_edit[:auto_join_users])
      auto_join_limiter(channel_from_params).performed!
    end

    with_service(Chat::UpdateChannel, **params_to_edit) do
      on_success do
        render_serialized(
          result.channel,
          Chat::ChannelSerializer,
          root: "channel",
          membership: result.channel.membership_for(current_user),
        )
      end
      on_model_not_found(:channel) { raise ActiveRecord::RecordNotFound }
      on_failed_policy(:check_channel_permission) { raise Discourse::InvalidAccess }
      on_failed_policy(:no_direct_message_channel) { raise Discourse::InvalidAccess }
    end
  end

  private

  def channel_from_params
    @channel ||=
      begin
        channel = Chat::Channel.find(params.require(:channel_id))
        guardian.ensure_can_preview_chat_channel!(channel)
        channel
      end
  end

  def membership_from_params
    @membership ||=
      begin
        membership =
          Chat::ChannelMembershipManager.new(channel_from_params).find_for_user(current_user)
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
