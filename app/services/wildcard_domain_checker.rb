module WildcardDomainChecker
  def self.check_domain(domain, external_domain)
    escaped_domain =
      if domain[0] == '*'
        Regexp.escape(domain).sub("\\*", '\S*')
      else
        Regexp.escape(domain)
      end
    domain_regex = Regexp.new("^#{escaped_domain}$", 'i')

    external_domain.match(domain_regex)
  end
end
