class WebHookUserSerializer < UserSerializer
  # remove staff attributes
  def staff_attributes(*attrs)
  end
end
