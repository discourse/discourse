# This file is used by Rack-based servers to start the application.
require ::File.expand_path('../config/environment',  __FILE__)

# Unicorn self-process killer
require 'unicorn/worker_killer'

# Max memory size (RSS) per worker
# Args: Mem range to randomly restart web workers (so restarts don't all happen at same time. Default = 190mb <-> 230mb)
use Unicorn::WorkerKiller::Oom, ((ENV['WEB_WORKER_MEM_MIN_MB'].to_i || 190) * (1024**2)), ((ENV['WEB_WORKER_MEM_MAX_MB'].to_i || 230) * (1024**2))

map ActionController::Base.config.try(:relative_url_root) || "/" do
  run Discourse::Application
end

