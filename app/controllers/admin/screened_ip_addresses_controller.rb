# frozen_string_literal: true

class Admin::ScreenedIpAddressesController < Admin::AdminController

  before_action :fetch_screened_ip_address, only: [:update, :destroy]

  def index
    filter = params[:filter]
    filter = IPAddr.handle_wildcards(filter)

    screened_ip_addresses = ScreenedIpAddress
    screened_ip_addresses = screened_ip_addresses.where("cidr :filter >>= ip_address", filter: filter) if filter.present?
    screened_ip_addresses = screened_ip_addresses.limit(200).order('match_count desc')

    begin
      screened_ip_addresses = screened_ip_addresses.to_a
    rescue ActiveRecord::StatementInvalid
      # postgresql throws a PG::InvalidTextRepresentation exception when filter isn't a valid cidr expression
      screened_ip_addresses = []
    end

    render_serialized(screened_ip_addresses, ScreenedIpAddressSerializer)
  end

  def create
    screened_ip_address = ScreenedIpAddress.new(allowed_params)
    if screened_ip_address.save
      render_serialized(screened_ip_address, ScreenedIpAddressSerializer)
    else
      render_json_error(screened_ip_address)
    end
  end

  def update
    if @screened_ip_address.update(allowed_params)
      render_serialized(@screened_ip_address, ScreenedIpAddressSerializer)
    else
      render_json_error(@screened_ip_address)
    end
  end

  def destroy
    @screened_ip_address.destroy
    render json: success_json
  end

  def roll_up
    subnets = ScreenedIpAddress.roll_up(current_user)
    render json: success_json.merge!(subnets: subnets)
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
