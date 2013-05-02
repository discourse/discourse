require_dependency 'current_user'

class StaffConstraint

  def matches?(request)
    return false unless request.session[:current_user_id].present?
    User.where("admin = 't' or moderator = 't'").where(id: request.session[:current_user_id].to_i).exists?
  end

end
