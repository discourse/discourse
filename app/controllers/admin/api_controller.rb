class Admin::ApiController < Admin::AdminController

  def index
    render_serialized(ApiKey.where(hidden: false).to_a, ApiKeySerializer)
  end

  def regenerate_key
    api_key = ApiKey.find_by(id: params[:id])
    raise Discourse::NotFound if api_key.blank?

    api_key.regenerate!(current_user)
    render_serialized(api_key, ApiKeySerializer)
  end

  def revoke_key
    api_key = ApiKey.find_by(id: params[:id])
    raise Discourse::NotFound if api_key.blank?

    api_key.destroy
    render body: nil
  end

  def create_master_key
    api_key = ApiKey.create_master_key
    render_serialized(api_key, ApiKeySerializer)
  end

end
