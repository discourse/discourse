# frozen_string_literal: true

module DiscourseWorkflows
  class UserSerializer < ApplicationSerializer
    attributes :id, :username, :name, :trust_level, :trust_level_name, :admin, :moderator, :staff

    def trust_level_name
      TrustLevel.name(object.trust_level)
    end

    def staff
      object.staff?
    end
  end
end
