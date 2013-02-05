require_dependency 'current_user'

class AdminConstraint

  def matches?(request)
    return false unless request.session[:current_user_id].present?
    User.where(id: request.session[:current_user_id].to_i).where(admin: true).exists?
  end

end