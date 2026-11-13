# frozen_string_literal: true

# Canonicalizes hostnames for host_list policy comparisons. Applies DNS
# equivalence only: surrounding whitespace, case, an optional trailing
# root-label dot, and IDNA (Unicode label <=> punycode). Deliberately does NOT
# widen label scope (no suffix stripping) so callers keep their exact-match or
# suffix-match semantics. Normalizing at comparison time rather than at write
# time protects already-stored setting values from past format drift.
class HostnameNormalizer
  def self.normalize(hostname)
    hostname = hostname.to_s.strip.downcase.sub(/\.+\z/, "")
    return hostname if hostname.empty? || hostname.ascii_only?

    begin
      ::Addressable::IDNA.to_ascii(hostname)
    rescue ::Addressable::Error, ArgumentError
      hostname
    end
  end

  def self.normalize_list(value)
    return nil if value.nil?
    value.to_s.split("|").map { |entry| normalize(entry) }.reject(&:empty?)
  end

  def self.equivalent?(hostname, other)
    hostname = normalize(hostname)
    other = normalize(other)
    !hostname.empty? && !other.empty? && hostname == other
  end

  def self.any_equivalent?(hostname, others)
    others.to_a.compact.any? { |other| equivalent?(hostname, other) }
  end

  def self.within?(hostname, domain)
    hostname = normalize(hostname)
    domain = normalize(domain)
    return false if hostname.empty? || domain.empty?
    hostname == domain || hostname.end_with?(".#{domain}")
  end

  def self.any_within?(hostname, domains)
    domains.to_a.compact.any? { |domain| within?(hostname, domain) }
  end
end
