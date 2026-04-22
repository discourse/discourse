# frozen_string_literal: true

class DiscourseReactions::CustomReactionsController < ApplicationController
  PAGE_SIZE = 20

  requires_plugin DiscourseReactions::PLUGIN_NAME

  before_action :ensure_logged_in, except: %i[reactions_users_list]

  def toggle
    post = fetch_post_from_params
    reaction = params[:reaction]

    return render_json_error(post) unless DiscourseReactions::Reaction.valid?(reaction)

    begin
      manager =
        DiscourseReactions::ReactionManager.new(
          reaction_value: params[:reaction],
          user: current_user,
          post: post,
        )
      manager.toggle!
    rescue ActiveRecord::RecordNotUnique
      # If the user already performed this action, it's probably due to a different browser tab
      # or non-debounced clicking. We can ignore.
    end

    post.publish_change_to_clients!(:acted)
    publish_change_to_clients!(
      post,
      reaction: manager.reaction_value,
      previous_reaction: manager.previous_reaction_value,
    )

    render_json_dump(post_serializer(post).as_json)
  end

  def reactions_given
    params.require(:username)
    user =
      fetch_user_from_params(
        include_inactive:
          current_user.try(:staff?) || (current_user && SiteSetting.show_inactive_accounts),
      )
    raise Discourse::NotFound unless guardian.can_see_profile?(user)

    reaction_users =
      DiscourseReactions::ReactionUser
        .joins(
          "INNER JOIN discourse_reactions_reactions ON discourse_reactions_reactions.id = discourse_reactions_reaction_users.reaction_id",
        )
        .joins(
          "INNER JOIN posts p ON p.id = discourse_reactions_reaction_users.post_id AND p.deleted_at IS NULL",
        )
        .joins("INNER JOIN topics t ON t.id = p.topic_id AND t.deleted_at IS NULL")
        .joins(
          "INNER JOIN posts p2 ON p2.topic_id = t.id AND p2.post_number = 1 AND p.deleted_at IS NULL",
        )
        .joins("LEFT JOIN categories c ON c.id = t.category_id")
        .includes(:user, :post, :reaction)
        .where(user_id: user.id)
        .where.not(discourse_reactions_reactions: { reaction_users_count: nil })

    reaction_users = secure_reaction_users!(reaction_users)

    if params[:before_reaction_user_id]
      reaction_users =
        reaction_users.where(
          "discourse_reactions_reaction_users.id < ?",
          params[:before_reaction_user_id].to_i,
        )
    end

    reaction_users = reaction_users.order(created_at: :desc).limit(PAGE_SIZE)

    render_serialized(reaction_users.to_a, UserReactionSerializer)
  end

  def reactions_received
    params.require(:username)
    user =
      fetch_user_from_params(
        include_inactive:
          current_user.try(:staff?) || (current_user && SiteSetting.show_inactive_accounts),
      )
    raise Discourse::InvalidAccess unless guardian.can_see_notifications?(user)

    posts = Post.joins(:topic).where(user_id: user.id)
    posts = guardian.filter_allowed_categories(posts)
    post_ids = posts.select(:id)

    reaction_users =
      DiscourseReactions::ReactionUser
        .joins(:reaction)
        .where(post_id: post_ids)
        .where.not(discourse_reactions_reactions: { reaction_users_count: nil })

    # Guarantee backwards compatibility if someone was calling this endpoint with the old param.
    # TODO(roman): Remove after the 2.9 release.
    before_reaction_id = params[:before_reaction_user_id]
    if before_reaction_id.blank? && params[:before_post_id]
      before_reaction_id = params[:before_post_id]
    end

    if before_reaction_id
      reaction_users =
        reaction_users.where("discourse_reactions_reaction_users.id < ?", before_reaction_id.to_i)
    end

    if params[:acting_username]
      reaction_users =
        reaction_users.joins(:user).where(users: { username: params[:acting_username] })
    end

    reaction_users = reaction_users.order(created_at: :desc).limit(PAGE_SIZE).to_a

    if params[:include_likes]
      # We do not want to include likes that also count as
      # a reaction, otherwise it is confusing in the UI. We
      # do the same on the likes-received endpoint.
      likes =
        PostAction
          .where(
            post_id: post_ids,
            deleted_at: nil,
            post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
          )
          .joins(<<~SQL)
            LEFT JOIN discourse_reactions_reaction_users ON
              discourse_reactions_reaction_users.post_id = post_actions.post_id
              AND discourse_reactions_reaction_users.user_id = post_actions.user_id
          SQL
          .where("discourse_reactions_reaction_users.id IS NULL")
          .order(created_at: :desc)
          .limit(PAGE_SIZE)

      if params[:before_like_id]
        likes = likes.where("post_actions.id < ?", params[:before_like_id].to_i)
      end

      if params[:acting_username]
        likes = likes.joins(:user).where(users: { username: params[:acting_username] })
      end

      reaction_users = reaction_users.concat(translate_to_reactions(likes))
      reaction_users = reaction_users.sort { |a, b| b.created_at <=> a.created_at }
    end

    render_serialized reaction_users.first(PAGE_SIZE), UserReactionSerializer
  end

  def reactions_users_list
    post = fetch_post_from_params
    page = params[:page].to_i.clamp(0..)
    limit = params[:limit].present? ? params[:limit].to_i.clamp(1, 50) : 30

    rows, total =
      DiscourseReactions::PostReactionsQuery.call(
        post: post,
        reaction_filter: params[:reaction_value],
        limit: limit,
        offset: page * limit,
      )

    users =
      rows.map do |row|
        {
          id: row.id,
          username: row.username,
          name: row.name,
          avatar_template: User.avatar_template(row.username, row.uploaded_avatar_id),
          reaction: row.reaction,
        }
      end

    render_json_dump(users: users, total_rows: total)
  end

  private

  def post_serializer(post)
    PostSerializer.new(post, scope: guardian, root: false)
  end

  def fetch_post_from_params
    post_id = params[:post_id] || params[:id]
    post = Post.find(post_id)
    guardian.ensure_can_see!(post)
    post
  end

  def publish_change_to_clients!(post, reaction: nil, previous_reaction: nil)
    message = { post_id: post.id, reactions: [reaction, previous_reaction].compact.uniq }

    opts = {}
    secure_audience = post.topic.secure_audience_publish_messages
    opts = secure_audience if secure_audience[:user_ids] != [] && secure_audience[:group_ids] != []

    MessageBus.publish("/topic/#{post.topic.id}/reactions", message, opts)
  end

  def secure_reaction_users!(reaction_users)
    builder = DB.build("/*where*/")
    UserAction.apply_common_filters(builder, current_user.id, guardian)
    reaction_users.where(builder.to_sql.delete_prefix("/*where*/").delete_prefix("WHERE"))
  end

  def translate_to_reactions(likes)
    likes.map do |like|
      DiscourseReactions::ReactionUser.new(
        id: like.id,
        post: like.post,
        user: like.user,
        created_at: like.created_at,
        reaction:
          DiscourseReactions::Reaction.new(
            id: like.id,
            reaction_type: "emoji",
            post_id: like.post_id,
            reaction_value: DiscourseReactions::Reaction.main_reaction_id,
            created_at: like.created_at,
            reaction_users_count: 1,
          ),
      )
    end
  end
end
