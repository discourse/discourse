# frozen_string_literal: true

class Chat::Api::ChannelsStatusController < Chat::Api::ChannelsController
  def update
    Chat::UpdateChannelStatus.call(service_params) do
      on_success { |channel:| render_serialized(channel, Chat::ChannelSerializer, root: "channel") }
      on_model_not_found(:channel) { raise ActiveRecord::RecordNotFound }
      on_failed_policy(:check_channel_permission) { raise Discourse::InvalidAccess }
      on_failure { render(json: failed_json, status: 422) }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
    end
  end
end
