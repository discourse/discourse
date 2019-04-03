class ReviewableUserSerializer < ReviewableSerializer

  payload_attributes(
    :username,
    :email,
    :name
  )

end
