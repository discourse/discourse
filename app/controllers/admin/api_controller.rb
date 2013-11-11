class Admin::ApiController < Admin::AdminController
  def index
    render json: {key: SiteSetting.api_key}
  end

  def generate_key
    SiteSetting.generate_api_key!
    render json: {key: SiteSetting.api_key}
  end
end
