# frozen_string_literal: true

module DiscourseWorkflows
  class UserSerializer < ApplicationSerializer
    attributes :id,
               :username,
               :name,
               :trust_level,
               :trust_level_name,
               :admin,
               :moderator,
               :staff,
               :created_at,
               :approved,
               :silenced,
               :suspended,
               :uploaded_avatar_id,
               :avatar_template,
               :locale

    def trust_level_name
      TrustLevel.name(object.trust_level)
    end

    def staff
      object.staff?
    end

    def silenced
      object.silenced?
    end

    def suspended
      object.suspended?
    end

    def locale
      object.effective_locale
    end
  end
end
