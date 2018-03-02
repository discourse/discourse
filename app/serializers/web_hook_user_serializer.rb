class WebHookUserSerializer < UserSerializer
  attributes :external_id

  # remove staff attributes
  def staff_attributes(*attrs)
  end

  def include_email?
    scope.is_admin?
  end

  def include_external_id?
    scope.is_admin? && object.single_sign_on_record
  end

  def external_id
    object.single_sign_on_record.external_id
  end

end
