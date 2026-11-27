# frozen_string_literal: true

# Specs enable the primitives they test, so the test database starts with none.
if !Rails.env.test? && Migration::Helpers.new_site? && !McpPrimitive.exists?
  McpPrimitiveUpdater.enable_defaults!
end
