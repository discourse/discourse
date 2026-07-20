# frozen_string_literal: true

class Admin::BrowserTrafficController < Admin::AdminController
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
    raw_filters = params[:browser_traffic_filters]
    return {} if raw_filters.nil?
    raise BrowserTrafficExplorerQuery::InvalidParameter unless raw_filters.respond_to?(:permit)

    allowed_keys = BrowserTrafficExplorerQuery::FACETS.keys
    raise BrowserTrafficExplorerQuery::InvalidParameter if (raw_filters.keys - allowed_keys).any?

    raw_filters.permit(*allowed_keys).to_h
  end
end
