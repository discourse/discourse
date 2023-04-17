# frozen_string_literal: true

module Chat
  class MessageUserSerializer < BasicUserWithStatusSerializer
    attributes :moderator?, :admin?, :staff?, :moderator?, :new_user?, :primary_group_name

    def moderator?
      !!(object&.moderator?)
    end

    def admin?
      !!(object&.admin?)
    end

    def staff?
      !!(object&.staff?)
    end

    def new_user?
      object.trust_level == TrustLevel[0]
    end

    def primary_group_name
      return nil unless object && object.primary_group_id
      object.primary_group.name if object.primary_group
    end
  end
end
