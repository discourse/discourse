class ServiceWorkersController < ApplicationController
  layout false
  skip_before_filter :preload_json, :check_xhr, :verify_authenticity_token

  def push
    render file: Rails.application.assets.find_asset('push_service_worker.js').pathname, content_type: Mime::JS
  end
end
