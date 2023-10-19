# frozen_string_literal: true

module Chat
  class UserWithCustomFieldsAndStatusSerializer < ::UserWithCustomFieldsSerializer
    attributes :status

    def include_status?
      predicate = SiteSetting.enable_user_status && user.has_status?

      if user.association(:user_option).loaded?
        predicate = predicate && !user.user_option.hide_profile_and_presence
      end

      predicate
    end

    def status
      ::UserStatusSerializer.new(user.user_status, root: false)
    end
  end
end
