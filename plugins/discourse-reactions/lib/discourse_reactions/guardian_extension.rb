# frozen_string_literal: true

module DiscourseReactions::GuardianExtension
  def can_delete_reaction_user?(reaction_user)
    reaction_user.can_undo?
  end
end
