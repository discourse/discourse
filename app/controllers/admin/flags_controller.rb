require 'flag_query'

class Admin::FlagsController < Admin::AdminController

  def self.flags_per_page
    10
  end

  def index
    # we may get out of sync, fix it here
    PostAction.update_flagged_posts_count

    offset = params[:offset].to_i
    per_page = Admin::FlagsController.flags_per_page

    posts, topics, users, post_actions, total_rows = FlagQuery.flagged_posts_report(
      current_user,
      filter: params[:filter],
      user_id: params[:user_id],
      offset: offset,
      topic_id: params[:topic_id],
      per_page: per_page,
      rest_api: params[:rest_api].present?
    )

    if params[:rest_api]
      meta = {
        types: {
          disposed_by: 'user'
        }
      }

      if (total_rows || 0) > (offset + per_page)
        meta[:total_rows_flagged_posts] = total_rows
        meta[:load_more_flagged_posts] = admin_flags_filtered_path(
          filter: params[:filter],
          offset: offset + per_page,
          rest_api: params[:rest_api],
          topic_id: params[:topic_id]
        )
      end

      render_json_dump(
        {
          flagged_posts: posts,
          topics: serialize_data(topics, FlaggedTopicSerializer),
          users: serialize_data(users, FlaggedUserSerializer),
          post_actions: post_actions
        },
        rest_serializer: true,
        meta: meta
      )
    else
      render_json_dump(
        posts: posts,
        topics: serialize_data(topics, FlaggedTopicSerializer),
        users: serialize_data(users, FlaggedUserSerializer)
      )
    end
  end

  def agree
    params.permit(:id, :action_on_post)
    post = Post.find(params[:id])

    DiscourseEvent.trigger(
      :before_staff_flag_action,
      type: 'agree',
      post: post,
      action_on_post: params[:action_on_post],
      user: current_user
    )

    post_action_type = PostAction.post_action_type_for_post(post.id)

    keep_post = ['silenced', 'suspended', 'keep'].include?(params[:action_on_post])
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

    DiscourseEvent.trigger(
      :before_staff_flag_action,
      type: 'disagree',
      post: post,
      user: current_user
    )

    PostAction.clear_flags!(post, current_user)

    post.unhide!

    render body: nil
  end

  def defer
    params.permit(:id, :delete_post)
    post = Post.find(params[:id])

    DiscourseEvent.trigger(
      :before_staff_flag_action,
      type: 'defer',
      post: post,
      user: current_user
    )

    PostAction.defer_flags!(post, current_user, params[:delete_post])
    PostDestroyer.new(current_user, post).destroy if params[:delete_post]

    render body: nil
  end

end
