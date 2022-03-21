# frozen_string_literal: true

module BookmarkGuardian
  def can_delete_bookmark?(bookmark)
    @user == bookmark.user
  end

  def can_edit_bookmark?(bookmark)
    @user == bookmark.user
  end

  def can_create_bookmark?(bookmark)
    can_see_topic?(bookmark.topic)
  end
end
