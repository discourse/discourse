# frozen_string_literal: true

# pg performs inconsistently with large amounts of connections
Discourse.start_connection_reaper
