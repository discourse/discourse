require_dependency 'current_user'

class AdminConstraint

  def initialize(options={})
    @require_master = options[:require_master]
  end

  def matches?(request)
    return false if @require_master && RailsMultisite::ConnectionManagement.current_db != "default"
    provider = Discourse.current_user_provider.new(request.env)
    provider.current_user && provider.current_user.admin?
  end

end
