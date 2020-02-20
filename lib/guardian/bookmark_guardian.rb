# frozen_string_literal: true

module BookmarkGuardian
  def can_delete_bookmark?(bookmark)
    @user == bookmark.user
  end
end
