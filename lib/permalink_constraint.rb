class PermalinkConstraint

  def matches?(request)
    Permalink.where(url: Permalink.normalize_url(request.fullpath)).exists?
  end

end
