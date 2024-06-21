# frozen_string_literal: true

class HomePageConstraint
  def initialize(filter)
    @filter = filter
  end

  def matches?(request)
    return @filter == "finish_installation" if SiteSetting.has_login_hint?

    current_user = CurrentUser.lookup_from_env(request.env)
    # ensures we resolve the theme id as early as possible
    ThemeResolver.resolve_theme_id(request, Guardian.new(current_user), current_user)

    homepage = current_user&.user_option&.homepage || HomepageHelper.resolve(request, current_user)
    homepage == @filter
  rescue Discourse::InvalidAccess, Discourse::ReadOnly
    false
  end
end
