# frozen_string_literal: true

require "anonymous_action"

AnonymousAction.register("like_post") do |user, params|
  post = Post.find_by(id: params["post_id"])
  next if !post || !user.guardian.can_see?(post)
  PostActionCreator.like(user, post)
end
