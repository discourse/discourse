# frozen_string_literal: true

# This file is used by Rack-based servers to start the application.
ENV["DISCOURSE_RUNNING_IN_RACK"] = "1"

require ::File.expand_path('../config/environment',  __FILE__)

map ActionController::Base.config.try(:relative_url_root) || "/" do
  run Discourse::Application
end
