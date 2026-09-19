# frozen_string_literal: true

module DiscourseWorkflows
  class RedirectUrlValidator
    def self.valid?(url, allowed_domains)
      new(url, allowed_domains).valid?
    end

    def initialize(url, allowed_domains)
      @url = url
      @allowed_domains = allowed_domains
    end

    def valid?
      return false if @url.blank?

      uri = URI.parse(@url)
      return true if uri.relative? && uri.host.blank?
      return false unless uri.scheme.in?(%w[http https]) && uri.host.present?
      return true if uri.host.casecmp?(Discourse.current_hostname)

      allowed_host?(uri.host)
    rescue URI::InvalidURIError
      false
    end

    private

    def allowed_host?(host)
      host = host.to_s.downcase
      Array(@allowed_domains).any? do |domain|
        domain = domain.to_s.strip.downcase
        valid_domain_entry?(domain) && domain_matches?(host, domain)
      end
    end

    def valid_domain_entry?(domain)
      return false if domain.blank? || domain == "*"
      return false if domain.include?("/") || domain.include?(":")

      domain.start_with?("*.") ? domain.length > 2 : !domain.include?("*")
    end

    def domain_matches?(host, domain)
      if domain.start_with?("*.")
        suffix = domain.delete_prefix("*.")
        host.end_with?(".#{suffix}") && host != suffix
      else
        host == domain
      end
    end
  end
end
