require_dependency 'current_user'

class StaffConstraint

  def matches?(request)
    provider = Discourse.current_user_provider.new(request.env)
    provider.current_user && provider.current_user.staff?
  end

end
