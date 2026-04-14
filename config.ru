# frozen_string_literal: true

# This file is used by Rack-based servers to start the application.
ENV["DISCOURSE_RUNNING_IN_RACK"] = "1"

require ::File.expand_path('../config/environment',  __FILE__)

# rough disable of relative url root from env if multisite for subpath.
map "/" do
  run Discourse::Application
end
