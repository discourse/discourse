# frozen_string_literal: true

require "addressable/uri"
require "yaml"

class BrowserPageviewReferrerInspector
  REDDIT_HOSTS = %w[reddit.com old.reddit.com new.reddit.com np.reddit.com].freeze
  REFERERS_PATH = Rails.root.join("config/browser_pageview_referers.yml")
  SOURCE_NAME_MAX_LENGTH = 100

  RefererDefinition = Struct.new(:source, :medium, :domain, :parameters, keyword_init: true)
  ParsedReferer = Struct.new(:source, :medium, :term, :domain, keyword_init: true)

  def self.source_name(referrer)
    new(referrer).source_name
  end

  def self.parse(referrer)
    new(referrer).parse
  end

  def self.referer_for_host(host)
    normalized_host = normalize_host(host)
    return if normalized_host.blank?

    loop do
      referer = referers_by_domain[normalized_host]
      return referer if referer
      break if normalized_host.exclude?(".")

      normalized_host = normalized_host.split(".", 2).last
    end
  end

  def self.internal_source_names
    [Discourse.current_hostname].filter_map { |host| normalize_host(host) }.uniq
  end

  def self.internal_host?(host)
    internal_source_names.include?(normalize_host(host))
  end

  def self.referers_by_domain
    @referers_by_domain ||=
      begin
        referers = {}
        database = YAML.safe_load_file(REFERERS_PATH, aliases: true)

        database.each do |medium, sources|
          sources.each do |source, config|
            domains = Array(config["domains"]).filter_map { |domain| normalize_host(domain) }
            canonical_domain = canonical_domain_for(source, domains)
            parameters = Array(config["parameters"])

            domains.each do |domain|
              referers[domain] = RefererDefinition.new(
                source: source,
                medium: medium,
                domain: canonical_domain,
                parameters: parameters,
              )
            end
          end
        end

        referers
      end
  end

  def self.normalize_host(host)
    host.to_s.downcase.delete_suffix(".").delete_prefix("www.").presence
  end

  def self.canonical_domain_for(source, domains)
    return source.to_s.downcase if domains.blank?

    domains.find { |domain| domain == source.to_s.downcase } || domains.first
  end

  def initialize(referrer)
    @referrer = referrer.to_s.strip
  end

  def parse
    return if @referrer.blank?

    definition = self.class.referer_for_host(source_host)
    return if definition.blank?

    ParsedReferer.new(
      source: definition.source,
      medium: definition.medium,
      term: term_for(definition),
      domain: definition.domain,
    )
  end

  def source_name
    return BrowserPageviewDailyAggregate::DIRECT_SOURCE_NAME if @referrer.blank?

    host = source_host
    return BrowserPageviewDailyAggregate::OTHER_SOURCE_NAME if host.blank?
    return BrowserPageviewDailyAggregate::INTERNAL_SOURCE_NAME if self.class.internal_host?(host)

    referer = parse

    (normalize_reddit_source(host) || referer&.domain || host).slice(0, SOURCE_NAME_MAX_LENGTH)
  end

  private

  def parsed_referrer
    @parsed_referrer ||= Addressable::URI.parse(@referrer)
  rescue Addressable::URI::InvalidURIError, ArgumentError
    nil
  end

  def source_host
    @source_host ||=
      begin
        host = parsed_referrer&.host || @referrer[%r{\A[a-z][a-z0-9+.-]*://([^/?#:]+)}, 1]
        self.class.normalize_host(host)
      end
  end

  def normalize_reddit_source(host)
    return if !REDDIT_HOSTS.include?(host)

    reddit_path = parsed_referrer&.path&.match(%r{\A(/r/[^/?#]+)}i)&.[](1)
    return "reddit.com#{reddit_path}".slice(0, SOURCE_NAME_MAX_LENGTH) if reddit_path.present?

    "reddit.com"
  end

  def term_for(definition)
    return if definition.parameters.blank?

    query_values = parsed_referrer&.query_values || {}

    definition.parameters.each do |parameter|
      value = query_values[parameter]
      return value.first if value.is_a?(Array) && value.first.present?
      return value if value.present?
    end

    nil
  rescue Addressable::URI::InvalidURIError, ArgumentError
    nil
  end
end
