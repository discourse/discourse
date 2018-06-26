class HomePageConstraint
  def initialize(filter)
    @filter = filter
  end

  def matches?(request)
    return @filter == 'finish_installation' if SiteSetting.has_login_hint?

    provider = Discourse.current_user_provider.new(request.env)
    homepage = provider&.current_user&.user_option&.homepage || SiteSetting.anonymous_homepage
    homepage == @filter
  rescue Discourse::InvalidAccess
    false
  end
end
