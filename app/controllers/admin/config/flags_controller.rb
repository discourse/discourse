# frozen_string_literal: true

class Admin::Config::FlagsController < Admin::AdminController
  def toggle
    with_service(Flags::ToggleFlag) do
      on_success do
        Discourse.request_refresh!
        render(json: success_json)
      end
      on_failure { render(json: failed_json, status: 422) }
      on_model_not_found(:message) { raise Discourse::NotFound }
      on_failed_policy(:invalid_access) { raise Discourse::InvalidAccess }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
    end
  end

  def index
  end

  def new
  end

  def edit
  end

  def create
    with_service(Flags::CreateFlag) do
      on_success do
        Discourse.request_refresh!
        render json: result.flag, serializer: FlagSerializer
      end
      on_failure { render(json: failed_json, status: 422) }
      on_failed_policy(:invalid_access) { raise Discourse::InvalidAccess }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
    end
  end

  def update
    with_service(Flags::UpdateFlag) do
      on_success do
        Discourse.request_refresh!
        render json: result.flag, serializer: FlagSerializer
      end
      on_failure { render(json: failed_json, status: 422) }
      on_model_not_found(:message) { raise Discourse::NotFound }
      on_failed_policy(:not_system) { render_json_error(I18n.t("flags.errors.system")) }
      on_failed_policy(:not_used) { render_json_error(I18n.t("flags.errors.used")) }
      on_failed_policy(:invalid_access) { raise Discourse::InvalidAccess }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
    end
  end

  def reorder
    with_service(Flags::ReorderFlag) do
      on_success do
        Discourse.request_refresh!
        render(json: success_json)
      end
      on_failure { render(json: failed_json, status: 422) }
      on_model_not_found(:message) { raise Discourse::NotFound }
      on_failed_policy(:invalid_access) { raise Discourse::InvalidAccess }
      on_failed_policy(:invalid_move) { render_json_error(I18n.t("flags.errors.wrong_move")) }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
    end
  end

  def destroy
    with_service(Flags::DestroyFlag) do
      on_success do
        Discourse.request_refresh!
        render(json: success_json)
      end
      on_failure { render(json: failed_json, status: 422) }
      on_failed_policy(:not_system) { render_json_error(I18n.t("flags.errors.system")) }
      on_failed_policy(:not_used) { render_json_error(I18n.t("flags.errors.used")) }
      on_failed_policy(:invalid_access) { raise Discourse::InvalidAccess }
      on_failed_contract do |contract|
        render(json: failed_json.merge(errors: contract.errors.full_messages), status: 400)
      end
    end
  end
end
