# frozen_string_literal: true

# This file is used by Rack-based servers to start the application.
ENV["DISCOURSE_RUNNING_IN_RACK"] = "1"

require ::File.expand_path('../config/environment',  __FILE__)

# rough disable of relative url root from env if multisite for subpath.
p "[RAILS] Relative URL Root: #{ActionController::Base.config.try(:relative_url_root) || "/"}"
p "[RAILS] middleware: #{RailsMultisite::ConnectionManagement.dynamic_path_prefix_enabled?}"
p "[RAILS] #{RailsMultisite::ConnectionManagement.all_dbs}"

if RailsMultisite::ConnectionManagement.dynamic_path_prefix_enabled?
  root = '/'
else
  root = ActionController::Base.config.try(:relative_url_root) || "/"
end

map root do
  run Discourse::Application
end
