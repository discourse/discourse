# frozen_string_literal: true

module BookmarkGuardian
  def can_delete_bookmark?(bookmark)
    @user == bookmark.user
  end

  def can_edit_bookmark?(bookmark)
    @user == bookmark.user
  end

  def can_see_bookmarkable?(bookmark)
    bookmark.registered_bookmarkable.can_see?(self, bookmark)
  end
end
