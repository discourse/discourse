if Rails.env.production?
  # honestly, Rails should not be logging this, its real noisy
  Logster.store.ignore = [
  /^ActionController::RoutingError \(No route matches/
  ]
end
