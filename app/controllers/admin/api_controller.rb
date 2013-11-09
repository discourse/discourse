class Admin::ApiController < Admin::AdminController

  def index
    render_serialized(ApiKey.all.to_a, ApiKeySerializer)
  end

  def regenerate_key
    api_key = ApiKey.where(id: params[:id]).first
    raise Discourse::NotFound.new if api_key.blank?

    api_key.regenerate!(current_user)
    render_serialized(api_key, ApiKeySerializer)
  end

  def revoke_key
    api_key = ApiKey.where(id: params[:id]).first
    raise Discourse::NotFound.new if api_key.blank?

    api_key.destroy
    render nothing: true
  end

  def create_master_key
    api_key = ApiKey.create_master_key
    render_serialized(api_key, ApiKeySerializer)
  end

end
