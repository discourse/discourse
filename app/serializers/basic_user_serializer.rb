class BasicUserSerializer < ApplicationSerializer
  attributes :id, :username, :avatar_template

  def avatar_template
    if Hash === object
      User.avatar_template(user[:username], user[:uploaded_avatar_id])
    else
      user&.avatar_template
    end
  end

  def user
    object[:user] || object
  end

end
