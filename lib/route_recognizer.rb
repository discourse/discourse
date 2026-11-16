# frozen_string_literal: true

module RouteRecognizer
  MAX_SEPARATORS = 128
  private_constant :MAX_SEPARATORS

  def self.valid_path?(path)
    return true if path.bytesize <= MAX_SEPARATORS

    path = path.b unless path.encoding.ascii_compatible? && path.valid_encoding?
    path.count("./?") <= MAX_SEPARATORS
  end

  def self.recognize_path(path, method: :get)
    if path && !valid_path?(path)
      raise ActionController::RoutingError, "No route matches #{path.inspect}"
    end

    Rails.application.routes.recognize_path(path, method: method)
  end
end
