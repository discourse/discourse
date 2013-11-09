require_dependency 'post_creator'
require_dependency 'post_destroyer'
require_dependency 'distributed_memoizer'

class PostsController < ApplicationController

  # Need to be logged in for all actions here
  before_filter :ensure_logged_in, except: [:show, :replies, :by_number, :short_link, :versions, :reply_history]

  skip_before_filter :store_incoming_links, only: [:short_link]
  skip_before_filter :check_xhr, only: [:markdown,:short_link]

  def markdown
    post = Post.where(topic_id: params[:topic_id].to_i, post_number: (params[:post_number] || 1).to_i).first
    if post && guardian.can_see?(post)
      render text: post.raw, content_type: 'text/plain'
    else
      raise Discourse::NotFound
    end
  end

  def short_link
    post = Post.find(params[:post_id].to_i)
    IncomingLink.add(request,current_user)
    redirect_to post.url
  end

  def create
    params = create_params

    key = params_key(params)

    result = DistributedMemoizer.memoize(key, 120) do
      post_creator = PostCreator.new(current_user, params)
      post = post_creator.create
      if post_creator.errors.present?

        # If the post was spam, flag all the user's posts as spam
        current_user.flag_linked_posts_as_spam if post_creator.spam?

        "e" << MultiJson.dump(errors: post_creator.errors.full_messages)
      else
        post_serializer = PostSerializer.new(post, scope: guardian, root: false)
        post_serializer.topic_slug = post.topic.slug if post.topic.present?
        post_serializer.draft_sequence = DraftSequence.current(current_user, post.topic.draft_key)
        "s" << MultiJson.dump(post_serializer)
      end
    end


    payload = result[1..-1]
    if result[0] == "e"
      # don't memoize errors
      $redis.del(DistributedMemoizer.redis_key(key))
      render json: payload, status: 422
    else
      render json: payload
    end
  end

  def update
    params.require(:post)

    post = Post.where(id: params[:id]).first
    post.image_sizes = params[:image_sizes] if params[:image_sizes].present?
    guardian.ensure_can_edit!(post)

    # to stay consistent with the create api,
    #  we should allow for title changes and category changes here
    # we should also move all of this to a post updater.
    if post.post_number == 1 && (params[:title] || params[:post][:category])
      post.topic.title = params[:title] if params[:title]
      Topic.transaction do
        post.topic.change_category(params[:post][:category])
        post.topic.save
      end

      if post.topic.errors.present?
        render_json_error(post.topic)
        return
      end
    end

    revisor = PostRevisor.new(post)
    if revisor.revise!(current_user, params[:post][:raw])
      TopicLink.extract_from(post)
    end


    if post.errors.present?
      render_json_error(post)
      return
    end

    post_serializer = PostSerializer.new(post, scope: guardian, root: false)
    post_serializer.draft_sequence = DraftSequence.current(current_user, post.topic.draft_key)
    link_counts = TopicLink.counts_for(guardian,post.topic, [post])
    post_serializer.single_post_link_counts = link_counts[post.id] if link_counts.present?
    post_serializer.topic_slug = post.topic.slug if post.topic.present?

    result = {post: post_serializer.as_json}
    if revisor.category_changed.present?
      result[:category] = BasicCategorySerializer.new(revisor.category_changed, scope: guardian, root: false).as_json
    end

    render_json_dump(result)
  end

  def by_number
    @post = Post.where(topic_id: params[:topic_id], post_number: params[:post_number]).first
    guardian.ensure_can_see!(@post)
    @post.revert_to(params[:version].to_i) if params[:version].present?
    render_post_json(@post)
  end

  def reply_history
    @post = Post.where(id: params[:id]).first
    guardian.ensure_can_see!(@post)

    render_serialized(@post.reply_history, PostSerializer)
  end

  def show
    @post = find_post_from_params
    @post.revert_to(params[:version].to_i) if params[:version].present?
    render_post_json(@post)
  end

  def destroy
    post = find_post_from_params
    guardian.ensure_can_delete!(post)

    destroyer = PostDestroyer.new(current_user, post)
    destroyer.destroy

    render nothing: true
  end

  def recover
    post = find_post_from_params
    guardian.ensure_can_recover_post!(post)
    destroyer = PostDestroyer.new(current_user, post)
    destroyer.recover
    post.reload

    render_post_json(post)
  end

  def destroy_many

    params.require(:post_ids)

    posts = Post.where(id: post_ids_including_replies)
    raise Discourse::InvalidParameters.new(:post_ids) if posts.blank?

    # Make sure we can delete the posts
    posts.each {|p| guardian.ensure_can_delete!(p) }

    Post.transaction do
      topic_id = posts.first.topic_id
      posts.each {|p| PostDestroyer.new(current_user, p).destroy }
    end

    render nothing: true
  end

  # Retrieves a list of versions and who made them for a post
  def versions
    post = find_post_from_params
    render_serialized(post.all_versions, VersionSerializer)
  end

  # Direct replies to this post
  def replies
    post = find_post_from_params
    render_serialized(post.replies, PostSerializer)
  end

  def bookmark
    post = find_post_from_params
    if current_user
      if params[:bookmarked] == "true"
        PostAction.act(current_user, post, PostActionType.types[:bookmark])
      else
        PostAction.remove_act(current_user, post, PostActionType.types[:bookmark])
      end
    end
    render nothing: true
  end


  protected

    def find_post_from_params
      finder = Post.where(id: params[:id] || params[:post_id])

      # Include deleted posts if the user is staff
      finder = finder.with_deleted if current_user.try(:staff?)

      post = finder.first
      guardian.ensure_can_see!(post)
      post
    end

  def render_post_json(post)
    post_serializer = PostSerializer.new(post, scope: guardian, root: false)
    post_serializer.add_raw = true
    render_json_dump(post_serializer)
  end

  private

    def params_key(params)
      "post##" << Digest::SHA1.hexdigest(params
        .to_a
        .concat([["user", current_user.id]])
        .sort{|x,y| x[0] <=> y[0]}.join do |x,y|
          "#{x}:#{y}"
        end)
    end

    def create_params
      permitted = [
        :raw,
        :topic_id,
        :title,
        :archetype,
        :category,
        :target_usernames,
        :reply_to_post_number,
        :auto_close_days,
        :auto_track
      ]

      # param munging for WordPress
      params[:auto_track] = !(params[:auto_track].to_s == "false") if params[:auto_track]

      if api_key_valid?
        # php seems to be sending this incorrectly, don't fight with it
        params[:skip_validations] = params[:skip_validations].to_s == "true"
        permitted << :skip_validations
      end

      params.require(:raw)
      params.permit(*permitted).tap do |whitelisted|
          whitelisted[:image_sizes] = params[:image_sizes]
          # TODO this does not feel right, we should name what meta_data is allowed
          whitelisted[:meta_data] = params[:meta_data]
      end
    end
end
