class UserNameSerializer < ApplicationSerializer
  attributes :id, :username, :name, :uploaded_avatar_id, :avatar_template

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

end
