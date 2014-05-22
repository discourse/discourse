class BasicUserSerializer < ApplicationSerializer
  attributes :id, :username, :uploaded_avatar_id, :avatar_template

  def include_name?
    SiteSetting.enable_names?
  end

  # so weird we send a hash in here sometimes and an object others
  def include_uploaded_avatar_id?
    SiteSetting.allow_uploaded_avatars? &&
      (Hash === object ? user[:uploaded_avatar_id] : object.uploaded_avatar_id)
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
