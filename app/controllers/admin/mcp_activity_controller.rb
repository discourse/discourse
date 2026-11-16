# frozen_string_literal: true

class Admin::McpActivityController < Admin::AdminController
  def index
    limit = fetch_limit_from_params(default: 50, max: 100)
    cursor = fetch_int_from_params(:cursor, default: nil, min: 1)
    render json:
             McpActivityReport.new(
               limit: limit,
               cursor: cursor,
               end_date: params[:end_date],
               filter: params[:filter],
               outcome: params[:outcome],
               start_date: params[:start_date],
             ).call
  end
end
