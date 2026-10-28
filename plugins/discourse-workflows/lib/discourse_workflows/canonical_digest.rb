# frozen_string_literal: true

module DiscourseWorkflows
  # jsonb reorders object keys on the way back out, so digests are taken over
  # a key-sorted form to stay equal before and after a round trip.
  module CanonicalDigest
    def self.of(value)
      Digest::SHA256.hexdigest(JSON.generate(canonical(value)))
    end

    def self.canonical(value)
      case value
      when Hash
        value.keys.map(&:to_s).sort.to_h { |key| [key, canonical(value[key] || value[key.to_sym])] }
      when Array
        value.map { |entry| canonical(entry) }
      else
        value
      end
    end
  end
end
