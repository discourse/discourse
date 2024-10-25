# frozen_string_literal: true

class Chat::Api::ChannelsCurrentUserMembershipController < Chat::Api::ChannelsController
  def create
    guardian.ensure_can_join_chat_channel!(channel_from_params)

    render_serialized(
      channel_from_params.add(current_user),
      Chat::UserChannelMembershipSerializer,
      root: "membership",
    )
  end

  def destroy
    Chat::LeaveChannel.call(service_params) do
      on_success { render(json: success_json) }
      on_failure { render(json: failed_json, status: 422) }
      on_model_not_found(:channel) { raise Discourse::NotFound }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
    end
  end
end
