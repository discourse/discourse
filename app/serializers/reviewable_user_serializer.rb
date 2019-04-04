class ReviewableUserSerializer < ReviewableSerializer

  attributes :link_admin

  payload_attributes(
    :username,
    :email,
    :name
  )

  def link_admin
    scope.is_staff? && object.target.present?
  end

end
