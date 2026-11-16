# frozen_string_literal: true

module DiscourseDataExplorer
  class CachedResult < Data.define(:identity, :attributes)
    delegate :hash, :id, :query_id, to: :identity

    def [](name) = attributes[name.to_s]

    def fresh?(max_age: nil)
      return true unless max_age
      Time.iso8601(attributes["cached_at"]) >= max_age.ago
    rescue ArgumentError, TypeError
      false
    end
  end
end
