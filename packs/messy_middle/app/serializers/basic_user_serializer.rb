# frozen_string_literal: true

class BasicUserSerializer < ApplicationSerializer
  attributes :id, :username, :name, :avatar_template

  def name
    Hash === user ? user[:name] : user.try(:name)
  end

  def include_name?
    SiteSetting.enable_names?
  end

  def avatar_template
    if Hash === object
      User.avatar_template(user[:username], user[:uploaded_avatar_id])
    else
      user&.avatar_template
    end
  end

  def user
    object[:user] || object.try(:user) || object
  end

  def user_is_current_user
    object.id == scope.user&.id
  end

  def categories_with_notification_level(lookup_level)
    category_user_notification_levels
      .select { |id, level| level == CategoryUser.notification_levels[lookup_level] }
      .keys
  end

  def category_user_notification_levels
    @category_user_notification_levels ||= CategoryUser.notification_levels_for(user)
  end
end
