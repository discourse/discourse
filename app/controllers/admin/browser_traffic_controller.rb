# frozen_string_literal: true

class Admin::BrowserTrafficController < Admin::AdminController
  FILTER_PARAMS = {
    "normalized_url" => :url,
    "normalized_referrer" => :source,
    "country_code" => :country,
    "asn" => :network,
    "ip_address" => :ip,
    "browser" => :browser,
  }.freeze
  private_constant :FILTER_PARAMS

  def show
    raise Discourse::NotFound unless SiteSetting.enable_browser_traffic_explorer

    render json:
             BrowserTrafficExplorerQuery.call(
               start_date: params[:start_date],
               end_date: params[:end_date],
               filters: permitted_filters,
               snapshot_event_id: params[:snapshot_event_id],
             )
  rescue BrowserTrafficExplorerQuery::InvalidParameter
    render json: { error_type: "invalid_request" }, status: :unprocessable_entity
  rescue BrowserTrafficExplorerQuery::Timeout
    render json: { error_type: "timeout", retryable: true }, status: :service_unavailable
  end

  private

  def permitted_filters
    FILTER_PARAMS.each_with_object({}) do |(facet, parameter), filters|
      next unless params.key?(parameter)

      value = params[parameter]
      value = nil if value == "__null__"
      value = Integer(value, 10) if facet == "asn" && value.present?
      filters[facet] = value
    end
  rescue ArgumentError, TypeError
    raise BrowserTrafficExplorerQuery::InvalidParameter
  end
end
