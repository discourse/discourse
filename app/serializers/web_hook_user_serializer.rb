class WebHookUserSerializer < UserSerializer
  # remove staff attributes
  def staff_attributes(*attrs)
  end

  def include_email?
    scope.is_admin?
  end
end
