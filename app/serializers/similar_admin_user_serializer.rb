# frozen_string_literal: true

class SimilarAdminUserSerializer < AdminUserListSerializer
  attributes :can_be_suspended, :can_be_silenced

  def can_be_suspended
    scope.can_suspend?(object)
  end

  def can_be_silenced
    scope.can_silence_user?(object)
  end
end
