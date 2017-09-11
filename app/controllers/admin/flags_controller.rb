require 'flag_query'

class Admin::FlagsController < Admin::AdminController

  def self.flags_per_page
    10
  end

  def index
    # we may get out of sync, fix it here
    PostAction.update_flagged_posts_count

    posts, topics, users, post_actions = FlagQuery.flagged_posts_report(
      current_user,
      filter: params[:filter],
      offset: params[:offset].to_i,
      topic_id: params[:topic_id],
      per_page: Admin::FlagsController.flags_per_page,
      rest_api: params[:rest_api].present?
    )

    if posts.blank?
      render json: { posts: [], topics: [], users: [] }
    else
      if params[:rest_api]
        render_json_dump(
          {
            flagged_posts: posts,
            topics: serialize_data(topics, FlaggedTopicSerializer),
            users: serialize_data(users, FlaggedUserSerializer),
            post_actions: post_actions
          },
          rest_serializer: true,
          meta: {
            types: {
              disposed_by: 'user'
            }
          }
        )
      else
        render_json_dump(
          posts: posts,
          topics: serialize_data(topics, FlaggedTopicSerializer),
          users: serialize_data(users, FlaggedUserSerializer)
        )
      end
    end
  end

  def agree
    params.permit(:id, :action_on_post)

    post = Post.find(params[:id])
    post_action_type = PostAction.post_action_type_for_post(post.id)

    keep_post = params[:action_on_post] == "keep"
    delete_post = params[:action_on_post] == "delete"
    restore_post = params[:action_on_post] == "restore"

    PostAction.agree_flags!(post, current_user, delete_post)

    if delete_post
      PostDestroyer.new(current_user, post).destroy
    elsif restore_post
      PostDestroyer.new(current_user, post).recover
    elsif !keep_post
      PostAction.hide_post!(post, post_action_type)
    end

    render body: nil
  end

  def disagree
    params.permit(:id)
    post = Post.find(params[:id])

    PostAction.clear_flags!(post, current_user)

    post.unhide!

    render body: nil
  end

  def defer
    params.permit(:id, :delete_post)
    post = Post.find(params[:id])

    PostAction.defer_flags!(post, current_user, params[:delete_post])

    PostDestroyer.new(current_user, post).destroy if params[:delete_post]

    render body: nil
  end

end
