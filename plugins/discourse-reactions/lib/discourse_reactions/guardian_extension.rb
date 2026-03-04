# frozen_string_literal: true

module DiscourseReactions::GuardianExtension
  def can_delete_reaction_user?(reaction_user)
    reaction_user.can_undo?
  end

  def can_use_reactions?(post)
    post_can_act?(post, :like)
  end
end
