# frozen_string_literal: true

# Base class for appreciation providers.
#
# Subclass this and implement:
#   - type         → String ("like", "reaction", "boost", etc.)
#   - enabled?     → Boolean
#   - fetch_given(user:, before:, limit:, guardian:)    → [Appreciation]
#   - fetch_received(user:, before:, limit:, guardian:) → [Appreciation]
#
# Plugins register via DiscoursePluginRegistry.register_appreciation_provider(provider, plugin).
# The core likes provider is registered directly in Appreciations::List.
class AppreciationProvider
  def type
    raise NotImplementedError
  end

  def enabled?
    raise NotImplementedError
  end

  def fetch_given(user:, before:, limit:, guardian:)
    raise NotImplementedError
  end

  def fetch_received(user:, before:, limit:, guardian:)
    raise NotImplementedError
  end
end
