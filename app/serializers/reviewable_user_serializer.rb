class ReviewableUserSerializer < ReviewableSerializer

  target_attributes(
    :username,
    :email,
    :name
  )

end
