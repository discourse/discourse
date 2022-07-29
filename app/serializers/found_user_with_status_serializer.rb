# frozen_string_literal: true

class FoundUserWithStatusSerializer < FoundUserSerializer
  attributes :status

  def include_status?
    SiteSetting.enable_user_status && object.has_status?
  end

  def status
    UserStatusSerializer.new(object.user_status, root: false)
  end
end
