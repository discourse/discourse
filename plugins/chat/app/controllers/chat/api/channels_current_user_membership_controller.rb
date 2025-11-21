# frozen_string_literal: true

class Chat::Api::ChannelsCurrentUserMembershipController < Chat::Api::ChannelsController
  MEMBERSHIP_EDITABLE_PARAMS = %i[pinned]

  def create
    guardian.ensure_can_join_chat_channel!(channel_from_params)

    render_serialized(
      channel_from_params.add(current_user),
      Chat::UserChannelMembershipSerializer,
      root: "membership",
    )
  end

  def update
    Chat::UpdateUserChannelMembership.call(
      params:
        params
          .require(:membership)
          .permit(MEMBERSHIP_EDITABLE_PARAMS)
          .to_h
          .merge(channel_id: params[:channel_id]),
      guardian: guardian,
    ) do
      on_success do |membership:|
        render_serialized(membership, Chat::UserChannelMembershipSerializer, root: "membership")
      end
      on_model_not_found(:channel) { raise Discourse::NotFound }
      on_model_not_found(:membership) { raise Discourse::NotFound }
      on_failed_policy(:can_access_channel) { raise Discourse::InvalidAccess }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request)
      end
      on_failure { render(json: failed_json, status: :unprocessable_entity) }
    end
  end

  def destroy
    Chat::LeaveChannel.call(service_params) do
      on_success { render(json: success_json) }
      on_failure { render(json: failed_json, status: :unprocessable_entity) }
      on_model_not_found(:channel) { raise Discourse::NotFound }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: :bad_request)
      end
    end
  end
end
