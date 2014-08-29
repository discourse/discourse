class PermalinkConstraint

  def matches?(request)
    Permalink.where(url: request.fullpath[1..-1]).exists?
  end

end
