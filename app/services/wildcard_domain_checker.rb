module WildcardDomainChecker

  def self.check_domain(domain, external_domain)
    escaped_domain = domain[0] == "*" ? Regexp.escape(domain).sub("\\*", '\S*') : Regexp.escape(domain)
    domain_regex = Regexp.new("^#{escaped_domain}$", 'i')

    external_domain.match(domain_regex)
  end

end
