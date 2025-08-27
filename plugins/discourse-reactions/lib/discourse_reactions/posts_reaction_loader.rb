# frozen_string_literal: true

module DiscourseReactions::PostsReactionLoader
  def posts_with_reactions
    if SiteSetting.discourse_reactions_enabled
      posts = object.posts.includes(:post_actions, reactions: { reaction_users: :user })
      post_ids = posts.map(&:id).uniq
      posts_reaction_users_count = TopicViewSerializer.posts_reaction_users_count(post_ids)
      post_actions_with_reaction_users =
        DiscourseReactions::TopicViewSerializerExtension.load_post_action_reaction_users_for_posts(
          post_ids,
        )
      posts.each do |post|
        post.reaction_users_count = posts_reaction_users_count[post.id].to_i
        post.post_actions_with_reaction_users = post_actions_with_reaction_users[post.id] || {}
      end

      object.instance_variable_set(:@posts, posts)
    end
  end
end
