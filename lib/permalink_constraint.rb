# frozen_string_literal: true

class PermalinkConstraint

  def matches?(request)
    # note: /go/ handled in the router
    Permalink.where(url: Permalink.normalize_url(request.fullpath)).exists?
  end

end
