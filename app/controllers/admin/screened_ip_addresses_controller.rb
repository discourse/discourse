class Admin::ScreenedIpAddressesController < Admin::AdminController

  before_filter :fetch_screened_ip_address, only: [:update, :destroy]

  def index
    screened_ip_addresses = ScreenedIpAddress.limit(200).order('last_match_at desc').to_a
    render_serialized(screened_ip_addresses, ScreenedIpAddressSerializer)
  end

  def update
    if @screened_ip_address.update_attributes(allowed_params)
      render json: success_json
    else
      render_json_error(@screened_ip_address)
    end
  end

  def destroy
    @screened_ip_address.destroy
    render json: success_json
  end

  private

    def allowed_params
      params.require(:ip_address)
      params.permit(:ip_address, :action_name)
    end

    def fetch_screened_ip_address
      @screened_ip_address = ScreenedIpAddress.find(params[:id])
    end

end
