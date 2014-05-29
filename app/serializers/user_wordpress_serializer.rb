class UserWordpressSerializer < BasicUserSerializer

  include UrlHelper

  def avatar_template
    if Hash === object
      absolute User.avatar_template(user[:username], user[:uploaded_avatar_id])
    else
      absolute object.avatar_template
    end
  end

end
