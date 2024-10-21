# frozen_string_literal: true

class Chat::Api::ChannelsCurrentUserMembershipFollowsController < Chat::Api::ChannelsController
  def destroy
    Chat::UnfollowChannel.call(service_params) do
      on_success do |membership:|
        render_serialized(membership, Chat::UserChannelMembershipSerializer, root: "membership")
      end
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
      on_model_not_found(:channel) { raise Discourse::NotFound }
      on_failure { render(json: failed_json, status: 422) }
    end
  end
end
