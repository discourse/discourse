# frozen_string_literal: true

module ::Lovelace
  class ChecklistsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login

    before_action :ensure_admin, only: %i[configuration update admin_show admin_update]

    def configuration
      render "default/empty"
    end

    def show
      respond_to do |format|
        format.html { render "default/empty" }
        format.json { render json: Checklist.for_user(current_user) }
      end
    end

    def update
      Checklist.update!(params[:item_ids])
      render json: Checklist.for_user(current_user)
    end

    def admin_show
      render_configuration(Checklist.read)
    end

    def admin_update
      Checklist::Update.call(service_params) do
        on_success { |checklist:| render_configuration(checklist) }
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

    private

    def render_configuration(checklist)
      render json:
               checklist.merge(
                 "unmodified_seed_ids" => Checklist.unmodified_seed_ids(checklist["items"]),
               )
    end
  end
end
