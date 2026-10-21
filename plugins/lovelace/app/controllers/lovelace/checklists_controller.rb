# frozen_string_literal: true

module ::Lovelace
  class ChecklistsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login
    before_action :ensure_admin

    def show
      render json: Checklist.read
    end

    def update
      Checklist::Update.call(service_params) do
        on_success { |checklist:| render json: checklist }
        on_failed_policy(:plugin_enabled) { raise Discourse::NotFound }
        on_failed_policy(:can_configure_checklist) { raise Discourse::InvalidAccess }
        on_failed_contract do |contract|
          raise Discourse::InvalidParameters.new(contract.errors.first.message)
        end
        on_failed_policy(:revision_matches) do
          render json: { errors: [I18n.t("lovelace.checklist_conflict")] }, status: :conflict
        end
        on_failure { render json: failed_json, status: :unprocessable_entity }
      end
    end
  end
end
