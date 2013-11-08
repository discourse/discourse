require_dependency 'post_creator'
require_dependency 'post_destroyer'
require_dependency 'distributed_memoizer'

class Lp::PostsController < PostsController
  def create
    errors = []
    success = {topic: nil, comment: nil}

    topic_post_params = {
      skip_validations: true,
      auto_track: false,
      title: params[:topic_title],
      raw: params[:topic_description],
    }

    topic_post_creator = PostCreator.new(current_user, topic_post_params)
    topic_post = topic_post_creator.create

    if topic_post_creator.errors.present?
      errors << topic_post_creator.errors.full_messages
    else
      topic_post_serializer = PostSerializer.new(topic_post, scope: guardian, root: false)
      topic_post_serializer.topic_slug = topic_post.topic.slug
      success[:topic] = topic_post_serializer
    end

    comment_post_params = {
      skip_validations: true,
      auto_track: false,
      raw: params[:comment],
      topic_id: topic_post.topic.id
    }

    comment_user = User.find_by_email(params[:email])
    comment_post_creator = PostCreator.new(comment_user, comment_post_params)
    comment_post = comment_post_creator.create

    if comment_post_creator.errors.present?
      errors << comment_post_creator.errors.full_messages
    else
      comment_post_serializer = PostSerializer.new(comment_post, scope: guardian, root: false)
      success[:comment] = comment_post_serializer
    end

    unless errors.empty?
      render json: MultiJson.dump(errors), status: 422
    else
      render json: MultiJson.dump(success)
    end
  end
end
