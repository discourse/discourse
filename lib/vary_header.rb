# frozen_string_literal: true

module VaryHeader
  def ensure_vary_header
    response.headers["Vary"] ||= "Accept" if !params[:format]
  end
end
