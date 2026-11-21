# frozen_string_literal: true

class Chat::Admin::BotDiscoverabilityController < ::Admin::AdminController
  requires_plugin Chat::PLUGIN_NAME

  def update
    Chat::UpdateBotDiscoverability.call(service_params) do
      on_success { head :no_content }
      on_failed_policy(:can_manage_bots) { raise Discourse::InvalidAccess }
      on_model_not_found(:bot) { raise Discourse::NotFound }
      on_failed_contract { |contract| render_json_error(contract.errors.full_messages) }
    end
  end
end
