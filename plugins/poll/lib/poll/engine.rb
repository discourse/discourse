# frozen_string_literal: true

module DiscoursePoll
  DATA_PREFIX = "data-poll-"
  HAS_POLLS = "has_polls"
  DEFAULT_POLL_NAME = "poll"

  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscoursePoll
  end

  class Error < StandardError
  end
end
