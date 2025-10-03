# frozen_string_literal: true

module PostVoting
  class CommentsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_action :find_post, only: %i[load_more_comments create]
    before_action :ensure_post_voting_enabled, only: %i[load_more_comments create]
    before_action :ensure_logged_in, only: %i[create destroy update]

    def load_more_comments
      @guardian.ensure_can_see!(@post)
      params.require(:last_comment_id)

      if @post.reply_to_post_number.present? && @post.post_number != 1
        raise Discourse::InvalidParameters
      end

      comments =
        PostVotingComment
          .includes(:user)
          .where("id > ? AND post_id = ?", comments_params[:last_comment_id], @post.id)
          .order(id: :asc)

      render_serialized(comments, PostVotingCommentSerializer, root: "comments")
    end

    def create
      raise Discourse::InvalidAccess if !@guardian.can_create_post_on_topic?(@post.topic)

      comment =
        PostVoting::CommentCreator.create(
          user: current_user,
          post_id: @post.id,
          raw: comments_params[:raw],
        )
      if comment.errors.present?
        render_json_error(comment.errors.full_messages, status: 403)
      else
        DiscourseEvent.trigger(:post_voting_comment_created, comment, comment.user)
        render_serialized(comment, PostVotingCommentSerializer, root: false)
      end
    end

    def update
      params.require(:comment_id)
      params.require(:raw)

      comment = find_comment(params[:comment_id])

      @guardian.ensure_can_see!(comment.post)
      raise Discourse::InvalidAccess if !@guardian.can_edit_comment?(comment)

      if comment.update(raw: params[:raw])
        Scheduler::Defer.later("Publish post voting comment edited") do
          comment.post.publish_change_to_clients!(
            :post_voting_post_comment_edited,
            comment_id: comment.id,
            comment_raw: comment.raw,
            comment_cooked: comment.cooked,
          )
        end
        DiscourseEvent.trigger(:post_voting_comment_edited, comment, comment.user)
        render_serialized(comment, PostVotingCommentSerializer, root: false)
      else
        render_json_error(comment.errors.full_messages, status: 403)
      end
    end

    def destroy
      params.require(:comment_id)
      comment = find_comment(params[:comment_id])

      @guardian.ensure_can_see!(comment.post)
      raise Discourse::InvalidAccess if !@guardian.can_delete_comment?(comment)

      comment.trash!

      Scheduler::Defer.later("Publish trash post voting comment") do
        comment.post.publish_change_to_clients!(
          :post_voting_post_comment_trashed,
          comment_id: comment.id,
          comments_count: PostVotingComment.where(post_id: comment.post_id).count,
        )
      end

      render json: success_json
    end

    def flag
      RateLimiter.new(current_user, "flag_post_voting_comment", 4, 1.minutes).performed!
      permitted_params =
        params.permit(%i[comment_id flag_type_id message is_warning take_action queue_for_review])

      comment = PostVotingComment.find(permitted_params[:comment_id])

      flag_type_id = permitted_params[:flag_type_id].to_i

      if !ReviewableScore.types.values.include?(flag_type_id)
        raise Discourse::InvalidParameters.new(:flag_type_id)
      end

      result =
        PostVoting::CommentReviewQueue.new.flag_comment(
          comment,
          guardian,
          flag_type_id,
          permitted_params,
        )

      if result[:success]
        render json: success_json
      else
        render_json_error(result[:errors])
      end
    end

    private

    def comments_params
      params.require(:post_id)
      params.permit(:post_id, :last_comment_id, :raw)
    end

    def find_comment(comment_id)
      comment = PostVotingComment.find_by(id: comment_id)
      raise Discourse::NotFound if comment.blank?
      comment
    end

    def find_post
      @post = Post.find_by(id: comments_params[:post_id])
      raise Discourse::NotFound if @post.blank?
    end

    def ensure_post_voting_enabled
      raise Discourse::InvalidAccess if !@post.is_post_voting_topic?
    end
  end
end
