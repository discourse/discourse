# frozen_string_literal: true

module WildcardDomainChecker

  def self.check_domain(domain, external_domain)
    escaped_domain = domain[0] == "*" ? Regexp.escape(domain).sub("\\*", '\S*') : Regexp.escape(domain)
    domain_regex = Regexp.new("\\A#{escaped_domain}\\z", 'i')

    external_domain.match(domain_regex)
  end

end
