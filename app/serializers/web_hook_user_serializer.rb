class WebHookUserSerializer < UserSerializer
  # remove staff attributes
  def self.staff_attributes(*attrs)
    return
  end
end
