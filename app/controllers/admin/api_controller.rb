# frozen_string_literal: true

class Admin::ApiController < Admin::AdminController
  # Note: in the REST API, ApiKeys are referred to simply as "key"
  # If we used "api_key", then our user provider would try to use the value for authentication

  def index
    keys = ApiKey.where(hidden: false)

    # Put active keys first
    # Sort active keys by created_at, sort revoked keys by revoked_at
    keys = keys.order(<<~SQL)
      CASE WHEN revoked_at IS NULL THEN 0 ELSE 1 END,
      COALESCE(revoked_at, created_at) DESC
    SQL

    render_serialized(keys.to_a, ApiKeySerializer, root: 'keys')
  end

  def show
    api_key = ApiKey.find_by!(id: params[:id])
    render_serialized(api_key, ApiKeySerializer, root: 'key')
  end

  def update
    api_key = ApiKey.find_by!(id: params[:id])
    ApiKey.transaction do
      api_key.update!(update_params)
      log_api_key(api_key, UserHistory.actions[:api_key_update], changes: api_key.saved_changes)
    end
    render_serialized(api_key, ApiKeySerializer, root: 'key')
  end

  def destroy
    api_key = ApiKey.find_by!(id: params[:id])
    ApiKey.transaction do
      api_key.destroy
      log_api_key(api_key, UserHistory.actions[:api_key_destroy])
    end
    render json: success_json
  end

  def create
    api_key = ApiKey.new(update_params)
    ApiKey.transaction do
      api_key.created_by = current_user
      if username = params.require(:key).permit(:username)[:username].presence
        api_key.user = User.find_by_username(username)
        raise Discourse::NotFound unless api_key.user
      end
      api_key.save!
      log_api_key(api_key, UserHistory.actions[:api_key_create], changes: api_key.saved_changes)
    end
    render_serialized(api_key, ApiKeySerializer, root: 'key')
  end

  def undo_revoke_key
    api_key = ApiKey.find_by(id: params[:id])
    raise Discourse::NotFound if api_key.blank?

    ApiKey.transaction do
      api_key.update(revoked_at: nil)
      log_api_key_restore(api_key)
    end
    render_serialized(api_key, ApiKeySerializer)
  end

  def revoke_key
    api_key = ApiKey.find_by(id: params[:id])
    raise Discourse::NotFound if api_key.blank?

    ApiKey.transaction do
      api_key.update(revoked_at: Time.zone.now)
      log_api_key_revoke(api_key)
    end
    render_serialized(api_key, ApiKeySerializer)
  end

  private

  def update_params
    editable_fields = [:description]
    permitted_params = params.permit(key: [*editable_fields])[:key]
    raise Discourse::InvalidParameters unless permitted_params
    permitted_params
  end

  def log_api_key(*args)
    StaffActionLogger.new(current_user).log_api_key(*args)
  end

  def log_api_key_revoke(*args)
    StaffActionLogger.new(current_user).log_api_key_revoke(*args)
  end

  def log_api_key_restore(*args)
    StaffActionLogger.new(current_user).log_api_key_restore(*args)
  end

end
