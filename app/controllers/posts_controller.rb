require_dependency 'post_creator'
require_dependency 'post_destroyer'
require_dependency 'distributed_memoizer'

class PostsController < ApplicationController

  # Need to be logged in for all actions here
  before_filter :ensure_logged_in, except: [:show, :replies, :by_number, :short_link, :reply_history, :revisions, :expand_embed, :markdown, :raw, :cooked]

  skip_before_filter :store_incoming_links, only: [:short_link]
  skip_before_filter :check_xhr, only: [:markdown,:short_link]

  def markdown
    post = Post.find_by(topic_id: params[:topic_id].to_i, post_number: (params[:post_number] || 1).to_i)
    if post && guardian.can_see?(post)
      render text: post.raw, content_type: 'text/plain'
    else
      raise Discourse::NotFound
    end
  end

  def cooked
    post = find_post_from_params
    render json: {cooked: post.cooked}
  end

  def short_link
    post = Post.find(params[:post_id].to_i)
    IncomingLink.add(request,current_user)
    redirect_to post.url
  end

  def create
    params = create_params

    key = params_key(params)
    error_json = nil

    payload = DistributedMemoizer.memoize(key, 120) do
      post_creator = PostCreator.new(current_user, params)
      post = post_creator.create
      if post_creator.errors.present?

        # If the post was spam, flag all the user's posts as spam
        current_user.flag_linked_posts_as_spam if post_creator.spam?

        error_json = MultiJson.dump(errors: post_creator.errors.full_messages)
        raise Discourse::InvalidPost

      else
        post_serializer = PostSerializer.new(post, scope: guardian, root: false)
        post_serializer.topic_slug = post.topic.slug if post.topic.present?
        post_serializer.draft_sequence = DraftSequence.current(current_user, post.topic.draft_key)
        MultiJson.dump(post_serializer)
      end
    end

    render json: payload

  rescue Discourse::InvalidPost
    render json: error_json, status: 422
  end

  def update
    params.require(:post)

    post = Post.where(id: params[:id])
    post = post.with_deleted if guardian.is_staff?
    post = post.first
    post.image_sizes = params[:image_sizes] if params[:image_sizes].present?

    if too_late_to(:edit, post)
      render json: {errors: [I18n.t('too_late_to_edit')]}, status: 422
      return
    end

    guardian.ensure_can_edit!(post)

    # to stay consistent with the create api,
    #  we should allow for title changes and category changes here
    #  we should also move all of this to a post updater.
    if post.post_number == 1 && (params[:title] || params[:post][:category])
      post.topic.acting_user = current_user
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
    if revisor.revise!(current_user, params[:post][:raw], edit_reason: params[:post][:edit_reason])
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

  def show
    post = find_post_from_params
    display_post(post)
  end

  def by_number
    post = find_post_from_params_by_number
    display_post(post)
  end

  def reply_history
    post = find_post_from_params
    render_serialized(post.reply_history, PostSerializer)
  end

  def destroy
    post = find_post_from_params

    if too_late_to(:delete_post, post)
      render json: {errors: [I18n.t('too_late_to_edit')]}, status: 422
      return
    end

    guardian.ensure_can_delete!(post)

    destroyer = PostDestroyer.new(current_user, post)
    destroyer.destroy

    render nothing: true
  end

  def expand_embed
    render json: {cooked: TopicEmbed.expanded_for(find_post_from_params) }
  rescue
    render_json_error I18n.t('errors.embed.load_from_remote')
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
      posts.each {|p| PostDestroyer.new(current_user, p).destroy }
    end

    render nothing: true
  end

  # Direct replies to this post
  def replies
    post = find_post_from_params
    render_serialized(post.replies, PostSerializer)
  end

  def revisions
    post_revision = find_post_revision_from_params
    post_revision_serializer = PostRevisionSerializer.new(post_revision, scope: guardian, root: false)
    render_json_dump(post_revision_serializer)
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

  def wiki
    guardian.ensure_can_wiki!

    post = find_post_from_params
    post.wiki = params[:wiki]
    post.version += 1
    post.save

    render nothing: true
  end

  protected

  def find_post_revision_from_params
    post_id = params[:id] || params[:post_id]
    revision = params[:revision].to_i
    raise Discourse::InvalidParameters.new(:revision) if revision < 2

    post_revision = PostRevision.find_by(post_id: post_id, number: revision)
    post_revision.post = find_post_from_params

    guardian.ensure_can_see!(post_revision)
    post_revision
  end

  def render_post_json(post)
    post_serializer = PostSerializer.new(post, scope: guardian, root: false)
    post_serializer.add_raw = true
    post_serializer.topic_slug = post.topic.slug if post.topic.present?

    counts = PostAction.counts_for([post], current_user)
    if counts && counts = counts[post.id]
      post_serializer.post_actions = counts
    end
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
      :auto_close_time,
      :auto_track
    ]

    # param munging for WordPress
    params[:auto_track] = !(params[:auto_track].to_s == "false") if params[:auto_track]

    if api_key_valid?
      # php seems to be sending this incorrectly, don't fight with it
      params[:skip_validations] = params[:skip_validations].to_s == "true"
      permitted << :skip_validations

      # We allow `embed_url` via the API
      permitted << :embed_url
    end

    params.require(:raw)
    params.permit(*permitted).tap do |whitelisted|
        whitelisted[:image_sizes] = params[:image_sizes]
        # TODO this does not feel right, we should name what meta_data is allowed
        whitelisted[:meta_data] = params[:meta_data]
    end
  end

  def too_late_to(action, post)
    !guardian.send("can_#{action}?", post) && post.user_id == current_user.id && post.edit_time_limit_expired?
  end

  def display_post(post)
    post.revert_to(params[:version].to_i) if params[:version].present?
    render_post_json(post)
  end

  def find_post_from_params
    by_id_finder = Post.where(id: params[:id] || params[:post_id])
    find_post_using(by_id_finder)
  end

  def find_post_from_params_by_number
    by_number_finder = Post.where(topic_id: params[:topic_id], post_number: params[:post_number])
    find_post_using(by_number_finder)
  end

  def find_post_using(finder)
    # Include deleted posts if the user is staff
    finder = finder.with_deleted if current_user.try(:staff?)
    post = finder.first
    # load deleted topic
    post.topic = Topic.with_deleted.find(post.topic_id) if current_user.try(:staff?)
    guardian.ensure_can_see!(post)
    post
  end

end
