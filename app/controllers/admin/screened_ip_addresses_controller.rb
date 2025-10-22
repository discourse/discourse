# frozen_string_literal: true

class Admin::ScreenedIpAddressesController < Admin::StaffController
  before_action :can_see_ip
  before_action :fetch_screened_ip_address, only: %i[update destroy]

  def index
    filter = params[:filter]
    filter = IPAddr.handle_wildcards(filter)

    screened_ip_addresses = ScreenedIpAddress
    screened_ip_addresses =
      screened_ip_addresses.where(
        "cidr :filter >>= ip_address OR ip_address >>= cidr :filter",
        filter: filter,
      ) if filter.present?
    screened_ip_addresses = screened_ip_addresses.limit(200).order("match_count desc")

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

  private

  def can_see_ip
    raise Discourse::InvalidAccess.new if !guardian.can_see_ip?
  end

  def allowed_params
    params.require(:ip_address)
    params.permit(:ip_address, :action_name)
  end

  def fetch_screened_ip_address
    @screened_ip_address = ScreenedIpAddress.find(params[:id])
  end
end
