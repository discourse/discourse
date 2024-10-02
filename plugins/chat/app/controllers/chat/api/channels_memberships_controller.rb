# frozen_string_literal: true

class Chat::Api::ChannelsMembershipsController < Chat::Api::ChannelsController
  INDEX_LIMIT = 50

  def index
    params.permit(:username, :offset, :limit)

    offset = params[:offset].to_i
    limit = fetch_limit_from_params(default: INDEX_LIMIT, max: INDEX_LIMIT)

    memberships =
      Chat::ChannelMembershipsQuery.call(
        channel: channel_from_params,
        offset: offset,
        limit: limit,
        username: params[:username],
      )

    render_serialized(
      memberships,
      Chat::UserChannelMembershipSerializer,
      root: "memberships",
      meta: {
        total_rows: channel_from_params.user_count,
        load_more_url:
          "/chat/api/channels/#{channel_from_params.id}/memberships?offset=#{offset + limit}&limit=#{limit}&username=#{params[:username]}",
      },
    )
  end

  def create
    Chat::AddUsersToChannel.call(service_params) do
      on_success { render(json: success_json) }
      on_failure { render(json: failed_json, status: 422) }
      on_failed_policy(:can_add_users_to_channel) do
        render_json_error(I18n.t("chat.errors.users_cant_be_added_to_channel"))
      end
      on_failed_policy(:satisfies_dms_max_users_limit) do |policy|
        render_json_dump({ error: policy.reason }, status: 400)
      end
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
    end
  end
end
