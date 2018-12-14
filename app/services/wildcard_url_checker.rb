module WildcardUrlChecker

  def self.check_url(url, url_to_check)
    escaped_url = Regexp.escape(url).sub("\\*", '\S*')
    url_regex = Regexp.new("^#{escaped_url}$", 'i')

    url_to_check.match(url_regex)
  end

end
