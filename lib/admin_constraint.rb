require_dependency 'current_user'

class AdminConstraint

  def matches?(request)
    return false unless request.session[:current_user_id].present?
    User.admins.where(id: request.session[:current_user_id].to_i).exists?
  end

end
