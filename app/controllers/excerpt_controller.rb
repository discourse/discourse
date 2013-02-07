require_dependency 'post_excerpt_serializer'

class ExcerptController < ApplicationController


  def show
    requires_parameter(:url)

    uri = URI.parse(params[:url])
    route = Rails.application.routes.recognize_path(uri.path)

    case route[:controller]
      when 'topics'

        # If we have a post number, retrieve the last post. Otherwise, first post.
        topic_posts = Post.where(topic_id: route[:topic_id].to_i).order(:post_number)
        post = route.has_key?(:post_number) ? topic_posts.last : topic_posts.first
        guardian.ensure_can_see!(post)

        render :json => post, serializer: PostExcerptSerializer, root: false
      when 'users'
        user = User.where(username_lower: route[:username].downcase).first
        guardian.ensure_can_see!(user)
        render :json => user, serializer: UserExcerptSerializer, root: false
      when 'list'
        if route[:action] == 'category'
          category = Category.where(slug: route[:category]).first
          guardian.ensure_can_see!(category)
          render :json => category, serializer: CategoryExcerptSerializer, root: false
        end
      else
        render nothing: true, status: 404
      end

  rescue ActionController::RoutingError, Discourse::NotFound
    render nothing: true, status: 404
  end


end
