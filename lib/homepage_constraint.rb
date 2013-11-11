class HomePageConstraint
  def initialize(filter)
    @filter = filter
  end

  def matches?(request)
    homepage = request.session[:current_user_id].present? ? SiteSetting.homepage : SiteSetting.anonymous_homepage
    homepage == @filter
  end
end