require_dependency 'current_user'

class StaffConstraint

  def matches?(request)
    return false unless request.session[:current_user_id].present?
    User.staff.where(id: request.session[:current_user_id].to_i).exists?
  end

end
