# frozen_string_literal: true

class UserWordpressSerializer < BasicUserSerializer

  def avatar_template
    if Hash === object
      UrlHelper.absolute User.avatar_template(user[:username], user[:uploaded_avatar_id])
    else
      UrlHelper.absolute object.avatar_template
    end
  end

end
