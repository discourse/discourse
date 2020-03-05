# frozen_string_literal: true

class PermalinkConstraint

  def matches?(request)
    if request.fullpath.start_with?('/go/')
      return Permalink.match_go(request.fullpath).exists?
    end

    Permalink.where(url: Permalink.normalize_url(request.fullpath)).exists?
  end

end
