require_dependency 'new_post_manager'
require_dependency 'post_creator'
require_dependency 'post_destroyer'
require_dependency 'distributed_memoizer'
require_dependency 'new_post_result_serializer'

class PostsController < ApplicationController

  # Need to be logged in for all actions here
  before_filter :ensure_logged_in, except: [:show, :replies, :by_number, :short_link, :reply_history, :revisions, :latest_revision, :expand_embed, :markdown_id, :markdown_num, :cooked, :latest, :user_posts_feed]

  skip_before_filter :preload_json, :check_xhr, only: [:markdown_id, :markdown_num, :short_link, :latest, :user_posts_feed]

  def markdown_id
    markdown Post.find(params[:id].to_i)
  end

  def markdown_num
    if params[:revision].present?
      post_revision = find_post_revision_from_topic_id
      render text: post_revision.modifications[:raw].last, content_type: 'text/plain'
    else
      markdown Post.find_by(topic_id: params[:topic_id].to_i, post_number: (params[:post_number] || 1).to_i)
    end
  end

  def markdown(post)
    if post && guardian.can_see?(post)
      render text: post.raw, content_type: 'text/plain'
    else
      raise Discourse::NotFound
    end
  end

  def latest
    params.permit(:before)
    last_post_id = params[:before].to_i
    last_post_id = Post.last.id if last_post_id <= 0

    if params[:id] == "private_posts"
      raise Discourse::NotFound if current_user.nil?
      posts = Post.private_posts
                  .order(created_at: :desc)
                  .where('posts.id <= ?', last_post_id)
                  .where('posts.id > ?', last_post_id - 50)
                  .includes(topic: :category)
                  .includes(user: :primary_group)
                  .includes(:reply_to_user)
                  .limit(50)
      rss_description = I18n.t("rss_description.private_posts")
    else
      posts = Post.public_posts
                  .order(created_at: :desc)
                  .where('posts.id <= ?', last_post_id)
                  .where('posts.id > ?', last_post_id - 50)
                  .includes(topic: :category)
                  .includes(user: :primary_group)
                  .includes(:reply_to_user)
                  .limit(50)
      rss_description = I18n.t("rss_description.posts")
    end

    # Remove posts the user doesn't have permission to see
    # This isn't leaking any information we weren't already through the post ID numbers
    posts = posts.reject { |post| !guardian.can_see?(post) || post.topic.blank? }
    counts = PostAction.counts_for(posts, current_user)

    respond_to do |format|
      format.rss do
        @posts = posts
        @title = "#{SiteSetting.title} - #{rss_description}"
        @link = Discourse.base_url
        @description = rss_description
        render 'posts/latest', formats: [:rss]
      end
      format.json do
        render_json_dump(serialize_data(posts,
                                        PostSerializer,
                                        scope: guardian,
                                        root: params[:id],
                                        add_raw: true,
                                        add_title: true,
                                        all_post_actions: counts)
                                      )
      end
    end
  end

  def user_posts_feed
    params.require(:username)
    user = fetch_user_from_params

    posts = Post.public_posts
                .where(user_id: user.id)
                .where(post_type: Post.types[:regular])
                .order(created_at: :desc)
                .includes(:user)
                .includes(topic: :category)
                .limit(50)

    posts = posts.reject { |post| !guardian.can_see?(post) || post.topic.blank? }

    @posts = posts
    @title = "#{SiteSetting.title} - #{I18n.t("rss_description.user_posts", username: user.username)}"
    @link = "#{Discourse.base_url}/users/#{user.username}/activity"
    @description = I18n.t("rss_description.user_posts", username: user.username)
    render 'posts/latest', formats: [:rss]
  end

  def cooked
    post = find_post_from_params
    render json: {cooked: post.cooked}
  end

  def raw_email
    post = Post.find(params[:id].to_i)
    guardian.ensure_can_view_raw_email!(post)
    render json: { raw_email: post.raw_email }
  end

  def short_link
    post = Post.find(params[:post_id].to_i)
    # Stuff the user in the request object, because that's what IncomingLink wants
    if params[:user_id]
      user = User.find(params[:user_id].to_i)
      request['u'] = user.username_lower if user
    end

    guardian.ensure_can_see!(post)
    redirect_to post.url
  end

  def create

    @manager_params = create_params
    @manager_params[:first_post_checks] = !is_api?

    manager = NewPostManager.new(current_user, @manager_params)

    if is_api?
      memoized_payload = DistributedMemoizer.memoize(signature_for(@manager_params), 120) do
        result = manager.perform
        MultiJson.dump(serialize_data(result, NewPostResultSerializer, root: false))
      end

      parsed_payload = JSON.parse(memoized_payload)
      backwards_compatible_json(parsed_payload, parsed_payload['success'])
    else
      result = manager.perform
      json = serialize_data(result, NewPostResultSerializer, root: false)
      backwards_compatible_json(json, result.success?)
    end
  end

  def update
    params.require(:post)

    post = Post.where(id: params[:id])
    post = post.with_deleted if guardian.is_staff?
    post = post.first

    raise Discourse::NotFound if post.blank?

    post.image_sizes = params[:image_sizes] if params[:image_sizes].present?

    if too_late_to(:edit, post)
      return render json: { errors: [I18n.t('too_late_to_edit')] }, status: 422
    end

    guardian.ensure_can_edit!(post)

    changes = {
      raw: params[:post][:raw],
      edit_reason: params[:post][:edit_reason]
    }

    # to stay consistent with the create api, we allow for title & category changes here
    if post.is_first_post?
      changes[:title] = params[:title] if params[:title]
      changes[:category_id] = params[:post][:category_id] if params[:post][:category_id]
    end

    # We don't need to validate edits to small action posts by staff
    opts = {}
    if post.post_type == Post.types[:small_action] && current_user.staff?
      opts[:skip_validations] = true
    end

    topic = post.topic
    topic = Topic.with_deleted.find(post.topic_id) if guardian.is_staff?

    revisor = PostRevisor.new(post, topic)
    revisor.revise!(current_user, changes, opts)

    return render_json_error(post) if post.errors.present?
    return render_json_error(topic) if topic.errors.present?

    post_serializer = PostSerializer.new(post, scope: guardian, root: false)
    post_serializer.draft_sequence = DraftSequence.current(current_user, topic.draft_key)
    link_counts = TopicLink.counts_for(guardian, topic, [post])
    post_serializer.single_post_link_counts = link_counts[post.id] if link_counts.present?

    result = { post: post_serializer.as_json }
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
    render_serialized(post.reply_history(params[:max_replies].to_i, guardian), PostSerializer)
  end

  def destroy
    post = find_post_from_params
    RateLimiter.new(current_user, "delete_post", 3, 1.minute).performed! unless current_user.staff?

    if too_late_to(:delete_post, post)
      render json: {errors: [I18n.t('too_late_to_edit')]}, status: 422
      return
    end

    guardian.ensure_can_delete!(post)

    destroyer = PostDestroyer.new(current_user, post, { context: params[:context] })
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
    RateLimiter.new(current_user, "delete_post", 3, 1.minute).performed! unless current_user.staff?
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
    replies = post.replies.secured(guardian)
    render_serialized(replies, PostSerializer)
  end

  def revisions
    post_revision = find_post_revision_from_params
    post_revision_serializer = PostRevisionSerializer.new(post_revision, scope: guardian, root: false)
    render_json_dump(post_revision_serializer)
  end

  def latest_revision
    post_revision = find_latest_post_revision_from_params
    post_revision_serializer = PostRevisionSerializer.new(post_revision, scope: guardian, root: false)
    render_json_dump(post_revision_serializer)
  end

  def hide_revision
    post_revision = find_post_revision_from_params
    guardian.ensure_can_hide_post_revision!(post_revision)

    post_revision.hide!

    post = find_post_from_params
    post.public_version -= 1
    post.save

    render nothing: true
  end

  def show_revision
    post_revision = find_post_revision_from_params
    guardian.ensure_can_show_post_revision!(post_revision)

    post_revision.show!

    post = find_post_from_params
    post.public_version += 1
    post.save

    render nothing: true
  end

  def revert
    raise Discourse::NotFound unless guardian.is_staff?

    post_id = params[:id] || params[:post_id]
    revision = params[:revision].to_i
    raise Discourse::InvalidParameters.new(:revision) if revision < 2

    post_revision = PostRevision.find_by(post_id: post_id, number: revision)
    raise Discourse::NotFound unless post_revision

    post = find_post_from_params
    raise Discourse::NotFound if post.blank?

    post_revision.post = post
    guardian.ensure_can_see!(post_revision)
    guardian.ensure_can_edit!(post)
    return render_json_error(I18n.t('revert_version_same')) if post_revision.modifications["raw"].blank? && post_revision.modifications["title"].blank? && post_revision.modifications["category_id"].blank?

    topic = Topic.with_deleted.find(post.topic_id)

    changes = {}
    changes[:raw] = post_revision.modifications["raw"][0] if post_revision.modifications["raw"].present? && post_revision.modifications["raw"][0] != post.raw
    if post.is_first_post?
      changes[:title] = post_revision.modifications["title"][0] if post_revision.modifications["title"].present? && post_revision.modifications["title"][0] != topic.title
      changes[:category_id] = post_revision.modifications["category_id"][0] if post_revision.modifications["category_id"].present? && post_revision.modifications["category_id"][0] != topic.category.id
    end
    return render_json_error(I18n.t('revert_version_same')) unless changes.length > 0
    changes[:edit_reason] = "reverted to version ##{post_revision.number.to_i - 1}"

    revisor = PostRevisor.new(post, topic)
    revisor.revise!(current_user, changes)

    return render_json_error(post) if post.errors.present?
    return render_json_error(topic) if topic.errors.present?

    post_serializer = PostSerializer.new(post, scope: guardian, root: false)
    post_serializer.draft_sequence = DraftSequence.current(current_user, topic.draft_key)
    link_counts = TopicLink.counts_for(guardian, topic, [post])
    post_serializer.single_post_link_counts = link_counts[post.id] if link_counts.present?

    result = { post: post_serializer.as_json }
    if post.is_first_post?
      result[:topic] = BasicTopicSerializer.new(topic, scope: guardian, root: false).as_json if post_revision.modifications["title"].present?
      result[:category_id] = post_revision.modifications["category_id"][0] if post_revision.modifications["category_id"].present?
    end

    render_json_dump(result)
  end

  def bookmark
    post = find_post_from_params

    if params[:bookmarked] == "true"
      PostAction.act(current_user, post, PostActionType.types[:bookmark])
    else
      PostAction.remove_act(current_user, post, PostActionType.types[:bookmark])
    end

    tu = TopicUser.get(post.topic, current_user)

    render_json_dump(topic_bookmarked: tu.try(:bookmarked))
  end

  def wiki
    post = find_post_from_params
    guardian.ensure_can_wiki!(post)

    post.revise(current_user, { wiki: params[:wiki] })

    render nothing: true
  end

  def post_type
    guardian.ensure_can_change_post_type!

    post = find_post_from_params
    post.revise(current_user, { post_type: params[:post_type].to_i })

    render nothing: true
  end

  def rebake
    guardian.ensure_can_rebake!

    post = find_post_from_params
    post.rebake!(invalidate_oneboxes: true)

    render nothing: true
  end

  def unhide
    post = find_post_from_params

    guardian.ensure_can_unhide!(post)

    post.unhide!

    render nothing: true
  end

  def flagged_posts
    params.permit(:offset, :limit)
    guardian.ensure_can_see_flagged_posts!

    user = fetch_user_from_params
    offset = [params[:offset].to_i, 0].max
    limit = [(params[:limit] || 60).to_i, 100].min

    posts = user_posts(guardian, user.id, offset: offset, limit: limit)
              .where(id: PostAction.where(post_action_type_id: PostActionType.notify_flag_type_ids)
                                   .where(disagreed_at: nil)
                                   .select(:post_id))

    render_serialized(posts, AdminPostSerializer)
  end

  def deleted_posts
    params.permit(:offset, :limit)
    guardian.ensure_can_see_deleted_posts!

    user = fetch_user_from_params
    offset = [params[:offset].to_i, 0].max
    limit = [(params[:limit] || 60).to_i, 100].min

    posts = user_posts(guardian, user.id, offset: offset, limit: limit).where.not(deleted_at: nil)

    render_serialized(posts, AdminPostSerializer)
  end

  protected

  # We can't break the API for making posts. The new, queue supporting API
  # doesn't return the post as the root JSON object, but as a nested object.
  # If a param is present it uses that result structure.
  def backwards_compatible_json(json_obj, success)
    json_obj.symbolize_keys!
    if params[:nested_post].blank? && json_obj[:errors].blank? && json_obj[:action] != :enqueued
      json_obj = json_obj[:post]
    end

    if !success && GlobalSetting.try(:verbose_api_logging) && is_api?
      Rails.logger.error "Error creating post via API:\n\n#{json_obj.inspect}"
    end

    render json: json_obj, status: (!!success) ? 200 : 422
  end


  def find_post_revision_from_params
    post_id = params[:id] || params[:post_id]
    revision = params[:revision].to_i
    raise Discourse::InvalidParameters.new(:revision) if revision < 2

    post_revision = PostRevision.find_by(post_id: post_id, number: revision)
    raise Discourse::NotFound unless post_revision

    post_revision.post = find_post_from_params
    guardian.ensure_can_see!(post_revision)

    post_revision
  end

  def find_latest_post_revision_from_params
    post_id = params[:id] || params[:post_id]

    finder = PostRevision.where(post_id: post_id).order(:number)
    finder = finder.where(hidden: false) unless guardian.is_staff?
    post_revision = finder.last

    raise Discourse::NotFound unless post_revision

    post_revision.post = find_post_from_params
    guardian.ensure_can_see!(post_revision)

    post_revision
  end

  def find_post_revision_from_topic_id
    post = Post.find_by(topic_id: params[:topic_id].to_i, post_number: (params[:post_number] || 1).to_i)
    raise Discourse::NotFound unless guardian.can_see?(post)

    revision = params[:revision].to_i
    raise Discourse::NotFound if revision < 2

    post_revision = PostRevision.find_by(post_id: post.id, number: revision)
    raise Discourse::NotFound unless post_revision

    post_revision.post = post
    guardian.ensure_can_see!(post_revision)

    post_revision
  end

  private

  def user_posts(guardian, user_id, opts)
    posts = Post.includes(:user, :topic, :deleted_by, :user_actions)
                .where(user_id: user_id)
                .with_deleted
                .order(created_at: :desc)

    if guardian.user.moderator?

      # Awful hack, but you can't seem to remove the `default_scope` when joining
      # So instead I grab the topics separately
      topic_ids = posts.dup.pluck(:topic_id)
      topics = Topic.where(id: topic_ids).with_deleted.where.not(archetype: 'private_message')
      topics = topics.secured(guardian)

      posts = posts.where(topic_id: topics.pluck(:id))
    end

    posts.offset(opts[:offset])
         .limit(opts[:limit])
  end

  def create_params
    permitted = [
      :raw,
      :topic_id,
      :archetype,
      :category,
      :target_usernames,
      :reply_to_post_number,
      :auto_track,
      :typing_duration_msecs,
      :composer_open_duration_msecs,
    ]

    # param munging for WordPress
    params[:auto_track] = !(params[:auto_track].to_s == "false") if params[:auto_track]

    if api_key_valid?
      # php seems to be sending this incorrectly, don't fight with it
      params[:skip_validations] = params[:skip_validations].to_s == "true"
      permitted << :skip_validations

      # We allow `embed_url` via the API
      permitted << :embed_url

      # We allow `created_at` via the API
      permitted << :created_at

    end

    params.require(:raw)
    result = params.permit(*permitted).tap do |whitelisted|
      whitelisted[:image_sizes] = params[:image_sizes]
      # TODO this does not feel right, we should name what meta_data is allowed
      whitelisted[:meta_data] = params[:meta_data]
    end

    # Staff are allowed to pass `is_warning`
    if current_user.staff?
      params.permit(:is_warning)
      result[:is_warning] = (params[:is_warning] == "true")
    else
      result[:is_warning] = false
    end

    if current_user.staff? && SiteSetting.enable_whispers? && params[:whisper] == "true"
      result[:post_type] = Post.types[:whisper]
    end

    PostRevisor.tracked_topic_fields.each_key do |f|
      params.permit(f => [])
      result[f] = params[f] if params.has_key?(f)
    end

    # Stuff we can use in spam prevention plugins
    result[:ip_address] = request.remote_ip
    result[:user_agent] = request.user_agent
    result[:referrer] = request.env["HTTP_REFERER"]

    if usernames = result[:target_usernames]
      usernames = usernames.split(",")
      groups = Group.mentionable(current_user).where('name in (?)', usernames).pluck('name')
      usernames -= groups
      result[:target_usernames] = usernames.join(",")
      result[:target_group_names] = groups.join(",")
    end

    result
  end

  def signature_for(args)
    "post##" << Digest::SHA1.hexdigest(args
      .to_a
      .concat([["user", current_user.id]])
      .sort{|x,y| x[0] <=> y[0]}.join do |x,y|
        "#{x}:#{y}"
      end)
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
    raise Discourse::NotFound unless post
    # load deleted topic
    post.topic = Topic.with_deleted.find(post.topic_id) if current_user.try(:staff?)
    guardian.ensure_can_see!(post)
    post
  end

end
