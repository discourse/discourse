require 'flag_query'

class Admin::FlagsController < Admin::AdminController

  def index
    # we may get out of sync, fix it here
    PostAction.update_flagged_posts_count
    posts, topics, users = FlagQuery.flagged_posts_report(current_user, params[:filter], params[:offset].to_i, 10)

    if posts.blank?
      render json: { posts: [], topics: [], users: [] }
    else
      render json: MultiJson.dump({
        posts: posts,
        topics: serialize_data(topics, FlaggedTopicSerializer),
        users: serialize_data(users, FlaggedUserSerializer)
      })
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

    render nothing: true
  end

  def disagree
    params.permit(:id)
    post = Post.find(params[:id])

    PostAction.clear_flags!(post, current_user)

    post.unhide!

    render nothing: true
  end

  def defer
    params.permit(:id, :delete_post)
    post = Post.find(params[:id])

    PostAction.defer_flags!(post, current_user, params[:delete_post])

    PostDestroyer.new(current_user, post).destroy if params[:delete_post]

    render nothing: true
  end

end
