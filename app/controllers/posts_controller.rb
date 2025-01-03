# frozen_string_literal: true

class PostsController < ApplicationController
  # Bug with Rails 7+
  # see https://github.com/rails/rails/issues/44867
  self._flash_types -= [:notice]

  requires_login except: %i[
                   show
                   replies
                   by_number
                   by_date
                   short_link
                   reply_history
                   reply_ids
                   revisions
                   latest_revision
                   expand_embed
                   markdown_id
                   markdown_num
                   cooked
                   latest
                   user_posts_feed
                 ]

  skip_before_action :check_xhr,
                     only: %i[markdown_id markdown_num short_link latest user_posts_feed]

  MARKDOWN_TOPIC_PAGE_SIZE = 100

  def markdown_id
    markdown Post.find_by(id: params[:id].to_i)
  end

  def markdown_num
    if params[:revision].present?
      post_revision = find_post_revision_from_topic_id
      render plain: post_revision.modifications[:raw].last
    elsif params[:post_number].present?
      markdown Post.find_by(
                 topic_id: params[:topic_id].to_i,
                 post_number: params[:post_number].to_i,
               )
    else
      opts = params.slice(:page)
      opts[:limit] = MARKDOWN_TOPIC_PAGE_SIZE
      topic_view = TopicView.new(params[:topic_id], current_user, opts)
      content = topic_view.posts.map { |p| <<~MD }
          #{p.user.username} | #{p.updated_at} | ##{p.post_number}

          #{p.raw}

          -------------------------

        MD
      render plain: content.join
    end
  end

  def latest
    params.permit(:before)
    last_post_id = params[:before].to_i
    last_post_id = nil if last_post_id <= 0

    if params[:id] == "private_posts"
      raise Discourse::NotFound if current_user.nil?

      allowed_private_topics = TopicAllowedUser.where(user_id: current_user.id).select(:topic_id)

      allowed_groups = GroupUser.where(user_id: current_user.id).select(:group_id)
      allowed_private_topics_by_group =
        TopicAllowedGroup.where(group_id: allowed_groups).select(:topic_id)

      all_allowed =
        Topic
          .where(id: allowed_private_topics)
          .or(Topic.where(id: allowed_private_topics_by_group))
          .select(:id)

      posts =
        Post
          .private_posts
          .order(id: :desc)
          .includes(topic: :category)
          .includes(user: %i[primary_group flair_group])
          .includes(:reply_to_user)
          .limit(50)
      rss_description = I18n.t("rss_description.private_posts")

      posts = posts.where(topic_id: all_allowed) if !current_user.admin?
    else
      posts =
        Post
          .public_posts
          .visible
          .where(post_type: Post.types[:regular])
          .order(id: :desc)
          .includes(topic: :category)
          .includes(user: %i[primary_group flair_group])
          .includes(:reply_to_user)
          .where("categories.id" => Category.secured(guardian).select(:id))
          .limit(50)

      rss_description = I18n.t("rss_description.posts")
      @use_canonical = true
    end

    posts = posts.where("posts.id <= ?", last_post_id) if last_post_id

    posts = posts.to_a

    counts = PostAction.counts_for(posts, current_user)

    respond_to do |format|
      format.rss do
        @posts = posts
        @title = "#{SiteSetting.title} - #{rss_description}"
        @link = Discourse.base_url
        @description = rss_description
        render "posts/latest", formats: [:rss]
      end
      format.json do
        render_json_dump(
          serialize_data(
            posts,
            PostSerializer,
            scope: guardian,
            root: params[:id],
            add_raw: true,
            add_title: true,
            all_post_actions: counts,
          ),
        )
      end
    end
  end

  def user_posts_feed
    params.require(:username)
    user = fetch_user_from_params
    raise Discourse::NotFound unless guardian.can_see_profile?(user)

    posts =
      Post
        .public_posts
        .visible
        .where(user_id: user.id)
        .where(post_type: Post.types[:regular])
        .order(created_at: :desc)
        .includes(:user)
        .includes(topic: :category)
        .limit(50)

    posts = posts.reject { |post| !guardian.can_see?(post) || post.topic.blank? }

    respond_to do |format|
      format.rss do
        @posts = posts
        @title =
          "#{SiteSetting.title} - #{I18n.t("rss_description.user_posts", username: user.username)}"
        @link = "#{user.full_url}/activity"
        @description = I18n.t("rss_description.user_posts", username: user.username)
        render "posts/latest", formats: [:rss]
      end

      format.json do
        render_json_dump(serialize_data(posts, PostSerializer, scope: guardian, add_excerpt: true))
      end
    end
  end

  def cooked
    render json: { cooked: find_post_from_params.cooked }
  end

  def raw_email
    params.require(:id)
    post = Post.unscoped.find(params[:id].to_i)
    guardian.ensure_can_view_raw_email!(post)
    text, html = Email.extract_parts(post.raw_email)
    render json: { raw_email: post.raw_email, text_part: text, html_part: html }
  end

  def short_link
    post = Post.find_by(id: params[:post_id].to_i)
    raise Discourse::NotFound unless post

    # Stuff the user in the request object, because that's what IncomingLink wants
    if params[:user_id]
      user = User.find_by(id: params[:user_id].to_i)
      request["u"] = user.username_lower if user
    end

    guardian.ensure_can_see!(post)
    redirect_to path(post.url)
  end

  def create
    manager_params = create_params
    manager_params[:first_post_checks] = !is_api?
    manager_params[:advance_draft] = !is_api?

    manager = NewPostManager.new(current_user, manager_params)

    json =
      if is_api?
        memoized_payload =
          DistributedMemoizer.memoize(signature_for(manager_params), 120) do
            MultiJson.dump(serialize_data(manager.perform, NewPostResultSerializer, root: false))
          end

        JSON.parse(memoized_payload)
      else
        serialize_data(manager.perform, NewPostResultSerializer, root: false)
      end

    backwards_compatible_json(json)
  end

  def update
    params.require(:post)

    post = Post.where(id: params[:id])
    post = post.with_deleted if guardian.is_staff?
    post = post.first

    raise Discourse::NotFound if post.blank?

    post.image_sizes = params[:image_sizes] if params[:image_sizes].present?

    if !guardian.public_send("can_edit?", post) && post.user_id == current_user.id &&
         post.edit_time_limit_expired?(current_user)
      return render_json_error(I18n.t("too_late_to_edit"))
    end

    guardian.ensure_can_edit!(post)

    changes = { raw: params[:post][:raw], edit_reason: params[:post][:edit_reason] }

    Post.plugin_permitted_update_params.keys.each { |param| changes[param] = params[:post][param] }

    # keep `raw_old` for backwards compatibility
    original_text = params[:post][:original_text] || params[:post][:raw_old]
    if original_text.present? && original_text != post.raw
      return render_json_error(I18n.t("edit_conflict"), status: 409)
    end

    # to stay consistent with the create api, we allow for title & category changes here
    if post.is_first_post?
      changes[:title] = params[:title] if params[:title]
      changes[:category_id] = params[:post][:category_id] if params[:post][:category_id]

      if changes[:category_id] && changes[:category_id].to_i != post.topic.category_id.to_i
        category = Category.find_by(id: changes[:category_id])
        if category || (changes[:category_id].to_i == 0)
          guardian.ensure_can_move_topic_to_category!(category)
        else
          return render_json_error(I18n.t("category.errors.not_found"))
        end
      end
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

    post_serializer = PostSerializer.new(post, scope: guardian, root: false, add_raw: true)
    post_serializer.draft_sequence = DraftSequence.current(current_user, topic.draft_key)
    link_counts = TopicLink.counts_for(guardian, topic, [post])
    post_serializer.single_post_link_counts = link_counts[post.id] if link_counts.present?

    result = { post: post_serializer.as_json }
    if revisor.category_changed.present?
      result[:category] = BasicCategorySerializer.new(
        revisor.category_changed,
        scope: guardian,
        root: false,
      ).as_json
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

  def by_date
    post = find_post_from_params_by_date
    display_post(post)
  end

  def reply_history
    post = find_post_from_params

    topic_view =
      TopicView.new(
        post.topic,
        current_user,
        include_suggested: false,
        include_related: false,
        reply_history_for: post.id,
      )

    render_json_dump(TopicViewPostsSerializer.new(topic_view, scope: guardian).post_stream[:posts])
  end

  def reply_ids
    post = find_post_from_params
    render json: post.reply_ids(guardian).to_json
  end

  def destroy
    post = find_post_from_params
    force_destroy = ActiveModel::Type::Boolean.new.cast(params[:force_destroy])

    if force_destroy
      if !guardian.can_permanently_delete?(post)
        return render_json_error post.cannot_permanently_delete_reason(current_user), status: 403
      end
    else
      guardian.ensure_can_delete!(post)
    end

    unless guardian.can_moderate_topic?(post.topic)
      RateLimiter.new(
        current_user,
        "delete_post_per_min",
        SiteSetting.max_post_deletions_per_minute,
        1.minute,
      ).performed!
      RateLimiter.new(
        current_user,
        "delete_post_per_day",
        SiteSetting.max_post_deletions_per_day,
        1.day,
      ).performed!
    end

    PostDestroyer.new(
      current_user,
      post,
      context: params[:context],
      force_destroy: force_destroy,
    ).destroy

    render body: nil
  end

  def expand_embed
    render json: { cooked: TopicEmbed.expanded_for(find_post_from_params) }
  rescue StandardError
    render_json_error I18n.t("errors.embed.load_from_remote")
  end

  def recover
    post = find_post_from_params
    guardian.ensure_can_recover_post!(post)

    unless guardian.can_moderate_topic?(post.topic)
      RateLimiter.new(
        current_user,
        "delete_post_per_min",
        SiteSetting.max_post_deletions_per_minute,
        1.minute,
      ).performed!
      RateLimiter.new(
        current_user,
        "delete_post_per_day",
        SiteSetting.max_post_deletions_per_day,
        1.day,
      ).performed!
    end

    destroyer = PostDestroyer.new(current_user, post)
    destroyer.recover
    post.reload

    render_post_json(post)
  end

  def destroy_many
    params.require(:post_ids)
    agree_with_first_reply_flag = (params[:agree_with_first_reply_flag] || true).to_s == "true"

    posts = Post.where(id: post_ids_including_replies).order(:id)
    raise Discourse::InvalidParameters.new(:post_ids) if posts.blank?

    # Make sure we can delete the posts
    posts.each { |p| guardian.ensure_can_delete!(p) }

    Post.transaction do
      posts.each_with_index do |p, i|
        PostDestroyer.new(
          current_user,
          p,
          defer_flags: !(agree_with_first_reply_flag && i == 0),
        ).destroy
      end
    end

    render body: nil
  end

  def merge_posts
    params.require(:post_ids)
    posts = Post.where(id: params[:post_ids]).order(:id)
    raise Discourse::InvalidParameters.new(:post_ids) if posts.pluck(:id) == params[:post_ids]
    PostMerger.new(current_user, posts).merge
    render body: nil
  rescue PostMerger::CannotMergeError => e
    render_json_error(e.message)
  end

  MAX_POST_REPLIES = 20

  def replies
    params.permit(:after)

    after = [params[:after].to_i, 1].max
    post = find_post_from_params

    post_ids =
      post
        .replies
        .secured(guardian)
        .where(post_number: after + 1..)
        .limit(MAX_POST_REPLIES)
        .pluck(:id)

    if post_ids.blank?
      render_json_dump []
    else
      topic_view =
        TopicView.new(
          post.topic,
          current_user,
          post_ids:,
          include_related: false,
          include_suggested: false,
        )

      render_json_dump(
        TopicViewPostsSerializer.new(topic_view, scope: guardian).post_stream[:posts],
      )
    end
  end

  def revisions
    post = find_post_from_params
    raise Discourse::NotFound if post.hidden && !guardian.can_view_hidden_post_revisions?

    post_revision = find_post_revision_from_params
    post_revision_serializer =
      PostRevisionSerializer.new(post_revision, scope: guardian, root: false)
    render_json_dump(post_revision_serializer)
  end

  def latest_revision
    post = find_post_from_params
    raise Discourse::NotFound if post.hidden && !guardian.can_view_hidden_post_revisions?

    post_revision = find_latest_post_revision_from_params
    post_revision_serializer =
      PostRevisionSerializer.new(post_revision, scope: guardian, root: false)
    render_json_dump(post_revision_serializer)
  end

  def hide_revision
    post_revision = find_post_revision_from_params
    guardian.ensure_can_hide_post_revision!(post_revision)

    post_revision.hide!

    post = find_post_from_params
    post.public_version -= 1
    post.save

    post.publish_change_to_clients!(:revised)

    render body: nil
  end

  def permanently_delete_revisions
    guardian.ensure_can_permanently_delete_post_revisions!

    post = find_post_from_params
    raise Discourse::InvalidParameters.new(:post) if post.blank?
    raise Discourse::NotFound if post.revisions.blank?

    RateLimiter.new(
      current_user,
      "admin_permanently_delete_post_revisions",
      20,
      1.minute,
      apply_limit_to_staff: true,
    ).performed!

    ActiveRecord::Base.transaction do
      updated_at = Time.zone.now
      post.revisions.destroy_all
      post.update(version: 1, public_version: 1, last_version_at: updated_at)
      StaffActionLogger.new(current_user).log_permanently_delete_post_revisions(post)
    end

    post.rebake!

    render body: nil
  end

  def show_revision
    post_revision = find_post_revision_from_params
    guardian.ensure_can_show_post_revision!(post_revision)

    post_revision.show!

    post = find_post_from_params
    post.public_version += 1
    post.save

    post.publish_change_to_clients!(:revised)

    render body: nil
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
    if post_revision.modifications["raw"].blank? && post_revision.modifications["title"].blank? &&
         post_revision.modifications["category_id"].blank?
      return render_json_error(I18n.t("revert_version_same"))
    end

    topic = Topic.with_deleted.find(post.topic_id)

    changes = {}
    changes[:raw] = post_revision.modifications["raw"][0] if post_revision.modifications[
      "raw"
    ].present? && post_revision.modifications["raw"][0] != post.raw
    if post.is_first_post?
      changes[:title] = post_revision.modifications["title"][0] if post_revision.modifications[
        "title"
      ].present? && post_revision.modifications["title"][0] != topic.title
      changes[:category_id] = post_revision.modifications["category_id"][
        0
      ] if post_revision.modifications["category_id"].present? &&
        post_revision.modifications["category_id"][0] != topic.category.id
    end
    return render_json_error(I18n.t("revert_version_same")) if changes.length <= 0
    changes[:edit_reason] = I18n.with_locale(SiteSetting.default_locale) do
      I18n.t("reverted_to_version", version: post_revision.number.to_i - 1)
    end

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
      result[:topic] = BasicTopicSerializer.new(
        topic,
        scope: guardian,
        root: false,
      ).as_json if post_revision.modifications["title"].present?
      result[:category_id] = post_revision.modifications["category_id"][
        0
      ] if post_revision.modifications["category_id"].present?
    end

    render_json_dump(result)
  end

  def locked
    post = find_post_from_params
    locker = PostLocker.new(post, current_user)
    params[:locked] === "true" ? locker.lock : locker.unlock
    render_json_dump(locked: post.locked?)
  end

  def notice
    post = find_post_from_params
    raise Discourse::NotFound unless guardian.can_edit_staff_notes?(post.topic)

    old_notice = post.custom_fields[Post::NOTICE]

    if params[:notice].present?
      post.custom_fields[Post::NOTICE] = {
        type: Post.notices[:custom],
        raw: params[:notice],
        cooked: PrettyText.cook(params[:notice], features: { onebox: false }),
      }
    else
      post.custom_fields.delete(Post::NOTICE)
    end

    post.save_custom_fields

    StaffActionLogger.new(current_user).log_post_staff_note(
      post,
      old_value: old_notice&.[]("raw"),
      new_value: params[:notice],
    )

    render body: nil
  end

  def destroy_bookmark
    params.require(:post_id)

    bookmark_id =
      Bookmark.where(
        bookmarkable_id: params[:post_id],
        bookmarkable_type: "Post",
        user_id: current_user.id,
      ).pick(:id)
    destroyed_bookmark = BookmarkManager.new(current_user).destroy(bookmark_id)

    render json:
             success_json.merge(BookmarkManager.bookmark_metadata(destroyed_bookmark, current_user))
  end

  def wiki
    post = find_post_from_params
    params.require(:wiki)
    guardian.ensure_can_wiki!(post)

    post.revise(current_user, wiki: params[:wiki])

    render body: nil
  end

  def post_type
    guardian.ensure_can_change_post_type!
    post = find_post_from_params
    params.require(:post_type)
    raise Discourse::InvalidParameters.new(:post_type) if Post.types[params[:post_type].to_i].blank?

    post.revise(current_user, post_type: params[:post_type].to_i)

    render body: nil
  end

  def rebake
    guardian.ensure_can_rebake!

    post = find_post_from_params
    post.rebake!(invalidate_oneboxes: true, invalidate_broken_images: true)

    render body: nil
  end

  def unhide
    post = find_post_from_params

    guardian.ensure_can_unhide!(post)

    post.unhide!

    render body: nil
  end

  DELETED_POSTS_MAX_LIMIT = 100

  def deleted_posts
    params.permit(:offset, :limit)
    guardian.ensure_can_see_deleted_posts!

    user = fetch_user_from_params
    offset = [params[:offset].to_i, 0].max
    limit = fetch_limit_from_params(default: 60, max: DELETED_POSTS_MAX_LIMIT)

    posts = user_posts(guardian, user.id, offset: offset, limit: limit).where.not(deleted_at: nil)

    render_serialized(posts, AdminUserActionSerializer)
  end

  def pending
    params.require(:username)
    user = fetch_user_from_params
    raise Discourse::NotFound unless guardian.can_edit_user?(user)

    render_serialized(
      user.pending_posts.order(created_at: :desc),
      PendingPostSerializer,
      root: :pending_posts,
    )
  end

  protected

  def markdown(post)
    if post && guardian.can_see?(post)
      render plain: post.raw
    else
      raise Discourse::NotFound
    end
  end

  # We can't break the API for making posts. The new, queue supporting API
  # doesn't return the post as the root JSON object, but as a nested object.
  # If a param is present it uses that result structure.
  def backwards_compatible_json(json_obj)
    json_obj.symbolize_keys!

    success = json_obj[:success]

    if params[:nested_post].blank? && json_obj[:errors].blank? &&
         json_obj[:action].to_s != "enqueued"
      json_obj = json_obj[:post]
    end

    if !success && GlobalSetting.try(:verbose_api_logging) && (is_api? || is_user_api?)
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
    post =
      Post.find_by(topic_id: params[:topic_id].to_i, post_number: (params[:post_number] || 1).to_i)
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
    # Topic.unscoped is necessary to remove the default deleted_at: nil scope
    posts =
      Topic.unscoped do
        Post
          .includes(:user, :topic, :deleted_by, :user_actions)
          .where(user_id: user_id)
          .with_deleted
          .order(created_at: :desc)
      end

    if guardian.user.moderator? && !guardian.user.admin?
      # Awful hack, but you can't seem to remove the `default_scope` when joining
      # So instead I grab the topics separately
      topic_ids = posts.dup.pluck(:topic_id)
      topics = Topic.where(id: topic_ids).with_deleted.where.not(archetype: "private_message")
      topics = topics.secured(guardian)

      posts = posts.where(topic_id: topics)
    end

    posts.offset(opts[:offset]).limit(opts[:limit])
  end

  def create_params
    permitted = %i[
      raw
      topic_id
      archetype
      category
      target_recipients
      reply_to_post_number
      auto_track
      typing_duration_msecs
      composer_open_duration_msecs
      visible
      draft_key
    ]

    Post.plugin_permitted_create_params.each do |key, value|
      if value[:plugin].enabled?
        permitted << case value[:type]
        when :string
          key.to_sym
        when :array
          { key => [] }
        when :hash
          { key => {} }
        end
      end
    end

    # param munging for WordPress
    params[:auto_track] = !(params[:auto_track].to_s == "false") if params[:auto_track]
    params[:visible] = (params[:unlist_topic].to_s == "false") if params[:unlist_topic]

    if is_api?
      # php seems to be sending this incorrectly, don't fight with it
      params[:skip_validations] = params[:skip_validations].to_s == "true"
      permitted << :skip_validations

      params[:import_mode] = params[:import_mode].to_s == "true"
      permitted << :import_mode

      # We allow `embed_url` via the API
      permitted << :embed_url

      # We allow `created_at` via the API
      permitted << :created_at

      # We allow `external_id` via the API
      permitted << :external_id
    end

    result =
      params
        .permit(*permitted)
        .tap do |allowed|
          allowed[:image_sizes] = params[:image_sizes]

          if params.has_key?(:meta_data)
            Discourse.deprecate(
              "the :meta_data param is deprecated, use the :topic_custom_fields param instead",
              since: "3.2",
              drop_from: "3.3",
            )
          end

          topic_custom_fields = {}
          topic_custom_fields.merge!(editable_topic_custom_fields(:meta_data))
          topic_custom_fields.merge!(editable_topic_custom_fields(:topic_custom_fields))

          if topic_custom_fields.present?
            allowed[:topic_opts] = { custom_fields: topic_custom_fields }
          end
        end

    # Staff are allowed to pass `is_warning`
    if current_user.staff?
      params.permit(:is_warning)
      result[:is_warning] = (params[:is_warning] == "true")
    else
      result[:is_warning] = false
    end

    if params[:no_bump] == "true"
      raise Discourse::InvalidParameters.new(:no_bump) unless guardian.can_skip_bump?
      result[:no_bump] = true
    end

    if params[:shared_draft] == "true"
      raise Discourse::InvalidParameters.new(:shared_draft) unless guardian.can_create_shared_draft?

      result[:shared_draft] = true
    end

    if params[:whisper] == "true"
      unless guardian.can_create_whisper?
        raise Discourse::InvalidAccess.new(
                "invalid_whisper_access",
                nil,
                custom_message: "invalid_whisper_access",
              )
      end

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

    recipients = result[:target_recipients]

    if recipients
      recipients = recipients.split(",").map(&:downcase)
      groups =
        Group.messageable(current_user).where("lower(name) in (?)", recipients).pluck("lower(name)")
      recipients -= groups
      emails = recipients.select { |user| user.match(/@/) }
      recipients -= emails
      result[:target_usernames] = recipients.join(",")
      result[:target_emails] = emails.join(",")
      result[:target_group_names] = groups.join(",")
    end

    result.permit!
    result.to_h
  end

  def editable_topic_custom_fields(params_key)
    if (topic_custom_fields = params[params_key]).present?
      editable_topic_custom_fields = Topic.editable_custom_fields(guardian)

      if (
           unpermitted_topic_custom_fields =
             topic_custom_fields.except(*editable_topic_custom_fields)
         ).present?
        raise Discourse::InvalidParameters.new(
                "The following keys in :#{params_key} are not permitted: #{unpermitted_topic_custom_fields.keys.join(", ")}",
              )
      end

      topic_custom_fields.permit(*editable_topic_custom_fields).to_h
    else
      {}
    end
  end

  def signature_for(args)
    +"post##" << Digest::SHA1.hexdigest(
      args
        .to_h
        .to_a
        .concat([["user", current_user.id]])
        .sort { |x, y| x[0] <=> y[0] }
        .join { |x, y| "#{x}:#{y}" },
    )
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

  def find_post_from_params_by_date
    by_date_finder =
      TopicView
        .new(params[:topic_id], current_user)
        .filtered_posts
        .where("created_at >= ?", Time.zone.parse(params[:date]))
        .order("created_at ASC")
        .limit(1)

    find_post_using(by_date_finder)
  end

  def find_post_using(finder)
    # A deleted post can be seen by staff or a category group moderator for the topic.
    # But we must find the deleted post to determine which category it belongs to, so
    # we must find.with_deleted
    raise Discourse::NotFound unless post = finder.with_deleted.first
    raise Discourse::NotFound unless post.topic ||= Topic.with_deleted.find_by(id: post.topic_id)

    if post.deleted_at.present? || post.topic.deleted_at.present?
      raise Discourse::NotFound unless guardian.can_moderate_topic?(post.topic)
    end

    guardian.ensure_can_see!(post)

    post
  end
end
