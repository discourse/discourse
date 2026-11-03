# frozen_string_literal: true

# Our proxy config sets X-Forwarded-*, but passes a client's Forwarded header through unchanged.
Rack::Request.forwarded_priority = [:x_forwarded]
