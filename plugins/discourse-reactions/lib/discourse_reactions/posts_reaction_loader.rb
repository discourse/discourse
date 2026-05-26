# frozen_string_literal: true

module DiscourseReactions::PostsReactionLoader
  def posts_with_reactions
    if SiteSetting.discourse_reactions_enabled
      return if object.preloaded_post_data(:reactions)

      posts = object.posts
      user = object.respond_to?(:guardian) ? object.guardian.user : nil
      DiscourseReactions::ReactionsSerializerHelpers.preload_post_reactions(posts, user)
    end
  end
end
