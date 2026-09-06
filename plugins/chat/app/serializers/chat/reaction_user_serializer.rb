# frozen_string_literal: true

module Chat
  class ReactionUserSerializer < ::BasicUserSerializer
    attributes :reaction

    def name
      object.name
    end

    def avatar_template
      User.avatar_template(object.username, object.uploaded_avatar_id)
    end

    def reaction
      object.reaction
    end
  end
end
