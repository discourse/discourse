# frozen_string_literal: true

class Admin::ApiController < Admin::AdminController
  # Note: in the REST API, ApiKeys are referred to simply as "key"
  # If we used "api_key", then our user provider would try to use the value for authentication

  INDEX_LIMIT = 50

  def index
    offset = (params[:offset] || 0).to_i
    limit = fetch_limit_from_params(default: INDEX_LIMIT, max: INDEX_LIMIT)

    keys =
      ApiKey
        .where(hidden: false)
        .includes(:user)
        .order("revoked_at DESC NULLS FIRST, created_at DESC")
        .offset(offset)
        .limit(limit)

    render_json_dump(
      keys: serialize_data(keys, BasicApiKeySerializer),
      offset: offset,
      limit: limit,
    )
  end

  def show
    api_key = ApiKey.includes(:api_key_scopes).find_by!(id: params[:id])
    render_serialized(api_key, ApiKeySerializer, root: "key")
  end

  def scopes
    scopes =
      ApiKeyScope
        .scope_mappings
        .reduce({}) do |memo, (resource, actions)|
          memo.tap do |m|
            m[resource] = actions.map do |k, v|
              {
                scope_id: "#{resource}:#{k}",
                key: k,
                name: k.to_s.gsub("_", " "),
                params: v[:params],
                urls: v[:urls],
              }
            end
          end
        end

    render json: { scopes: scopes }
  end

  def update
    api_key = ApiKey.find_by!(id: params[:id])
    ApiKey.transaction do
      api_key.update!(update_params)
      log_api_key(api_key, UserHistory.actions[:api_key_update], changes: api_key.saved_changes)
    end
    render_serialized(api_key, ApiKeySerializer, root: "key")
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
      api_key.api_key_scopes = build_scopes
      if username = params.require(:key).permit(:username)[:username].presence
        api_key.user = User.find_by_username(username)
        raise Discourse::NotFound unless api_key.user
      end
      api_key.save!
      log_api_key(api_key, UserHistory.actions[:api_key_create], changes: api_key.saved_changes)
    end
    render_serialized(api_key, ApiKeySerializer, root: "key")
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

  def build_scopes
    params.require(:key)[:scopes].to_a.map do |scope_params|
      resource, action = scope_params[:scope_id].split(":")

      mapping = ApiKeyScope.scope_mappings.dig(resource.to_sym, action.to_sym)
      raise Discourse::InvalidParameters if mapping.nil? # invalid mapping

      ApiKeyScope.new(
        resource: resource,
        action: action,
        allowed_parameters: build_params(scope_params, mapping[:params]),
      )
    end
  end

  def build_params(scope_params, params)
    return if params.nil?

    scope_params
      .slice(*params)
      .tap do |allowed_params|
        allowed_params.each do |k, v|
          v.blank? ? allowed_params.delete(k) : allowed_params[k] = v.split(",")
        end
      end
  end

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
