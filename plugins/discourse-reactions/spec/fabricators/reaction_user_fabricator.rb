# frozen_string_literal: true

Fabricator(:reaction_user, class_name: "DiscourseReactions::ReactionUser") do
  transient :skip_post_action
  reaction { |attrs| attrs[:reaction] }
  user { |attrs| attrs[:user] || Fabricate(:user) }
  post { |attrs| attrs[:post] || Fabricate(:post) }

  after_create do |reaction_user, transients|
    if DiscourseReactions::Reaction.reactions_counting_as_like.include?(
         reaction_user.reaction.reaction_value,
       ) && !transients[:skip_post_action]
      Fabricate(
        :post_action,
        user: reaction_user.user,
        post: reaction_user.post,
        post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
        created_at: reaction_user.created_at,
      )
    end
  end
end
