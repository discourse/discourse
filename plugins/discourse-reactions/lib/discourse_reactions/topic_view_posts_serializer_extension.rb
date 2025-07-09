# frozen_string_literal: true

module DiscourseReactions::TopicViewPostsSerializerExtension
  include DiscourseReactions::PostsReactionLoader

  def posts
    posts_with_reactions
    super
  end
end
