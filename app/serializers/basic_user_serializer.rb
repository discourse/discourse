class BasicUserSerializer < ApplicationSerializer
  attributes :id, :username, :uploaded_avatar_id, :avatar_template, :letter_avatar_color

  def include_name?
    SiteSetting.enable_names?
  end

  def avatar_template
    if Hash === object
      User.avatar_template(user[:username], user[:uploaded_avatar_id])
    else
      object.avatar_template
    end
  end

  def user
    object[:user] || object
  end

  def letter_avatar_color
    if Hash === object
      User.letter_avatar_color(user[:username])
    else
      object.letter_avatar_color
    end
  end

end
