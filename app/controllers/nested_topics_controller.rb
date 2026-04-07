# frozen_string_literal: true

class NestedTopicsController < ApplicationController
  skip_before_action :check_xhr, only: %i[show context]

  before_action :ensure_nested_replies_enabled
  before_action :find_topic
  before_action :ensure_not_pm

  # GET /n/:slug/:topic_id (HTML + JSON)
  # HTML: preloads initial data into the Ember shell (crawlers redirect to flat view)
  # JSON page 0: includes topic metadata, OP post, sort, and message_bus_last_id
  # JSON page 1+: returns only roots for pagination
  def show
    sort = validated_sort

    if spa_boot_request?
      if use_crawler_layout?
        redirect_to "/t/#{params[:slug]}/#{params[:topic_id]}", status: :moved_permanently
        return
      end

      store_preloaded(
        "nested_topic_#{@topic.id}",
        MultiJson.dump(build_initial_roots_response(sort)),
      )
      render "default/empty"
      return
    end

    page = params[:page].to_i.clamp(0, 1000)

    if page == 0
      render json: build_initial_roots_response(sort)
      return
    end

    roots =
      loader
        .root_posts_scope(sort)
        .offset(page * NestedReplies::TreeLoader::ROOTS_PER_PAGE)
        .limit(NestedReplies::TreeLoader::ROOTS_PER_PAGE)
    roots = loader.load_posts_for_tree(roots).to_a
    has_more_roots = roots.size == NestedReplies::TreeLoader::ROOTS_PER_PAGE

    tree_data =
      loader.batch_preload_tree(roots, sort, max_depth: NestedReplies::TreeLoader::PRELOAD_DEPTH)
    children_map = tree_data[:children_map]

    all_posts = tree_data[:all_posts].dup

    preloader.prepare(all_posts)
    reply_counts = loader.direct_reply_counts(all_posts.map(&:post_number))
    descendant_counts = loader.total_descendant_counts(all_posts.map(&:id))

    render json: {
             roots:
               roots.map do |root|
                 serializer.serialize_tree(root, children_map, reply_counts, descendant_counts)
               end,
             has_more_roots: has_more_roots,
             page: page,
           }
  end

  # GET /n/:slug/:topic_id/children/:post_number
  def children
    parent_post_number = params[:post_number].to_i
    sort = validated_sort
    page = params[:page].to_i.clamp(0, 1000)
    depth = params[:depth].to_i.clamp(1, 100)

    flatten = SiteSetting.nested_replies_cap_nesting_depth && depth >= loader.configured_max_depth

    per_page = NestedReplies::TreeLoader::CHILDREN_PER_PAGE

    children_scope =
      if flatten
        loader.flat_descendants_scope(
          parent_post_number,
          sort: sort,
          offset: page * per_page,
          limit: per_page,
        )
      else
        scope = @topic.posts.where(reply_to_post_number: parent_post_number).where(post_number: 2..)
        scope = loader.apply_visibility(scope)
        scope = NestedReplies::Sort.apply(scope, sort)
        scope.offset(page * per_page).limit(per_page)
      end

    children_posts = loader.load_posts_for_tree(children_scope).to_a

    if flatten
      all_posts = children_posts
      children_map = {}
    else
      remaining_depth =
        if depth < loader.configured_max_depth
          [NestedReplies::TreeLoader::PRELOAD_DEPTH, loader.configured_max_depth - depth].min
        else
          0
        end
      tree_data = loader.batch_preload_tree(children_posts, sort, max_depth: remaining_depth)
      children_map = tree_data[:children_map]
      all_posts = tree_data[:all_posts]
    end

    preloader.prepare(all_posts)
    reply_counts = loader.direct_reply_counts(all_posts.map(&:post_number))
    descendant_counts = loader.total_descendant_counts(all_posts.map(&:id))

    render json: {
             children:
               children_posts.map { |child|
                 if flatten
                   serializer.serialize_post(child, reply_counts, descendant_counts).merge(
                     children: [],
                   )
                 else
                   serializer.serialize_tree(child, children_map, reply_counts, descendant_counts)
                 end
               },
             has_more: children_posts.size == NestedReplies::TreeLoader::CHILDREN_PER_PAGE,
             page: page,
           }
  end

  # GET /n/:slug/:topic_id/:post_number (HTML + JSON)
  # HTML: preloads context data into the Ember shell (crawlers redirect to flat view)
  # JSON param: context (integer) -- controls ancestor depth.
  #   nil/absent = windowed ancestor chain capped at max_depth (deep-links, notifications)
  #   0 = no ancestors, target at depth 0 ("Continue this thread")
  def context
    target_post_number = params[:post_number].to_i
    sort = validated_sort

    if spa_boot_request?
      if use_crawler_layout?
        redirect_to "/t/#{params[:slug]}/#{params[:topic_id]}/#{target_post_number}",
                    status: :moved_permanently
        return
      end

      store_preloaded(
        "nested_topic_#{@topic.id}",
        MultiJson.dump(
          build_context_response(target_post_number, sort, context_depth: params[:context]&.to_i),
        ),
      )
      render "default/empty"
      return
    end

    render json:
             build_context_response(target_post_number, sort, context_depth: params[:context]&.to_i)
  end

  # PUT /n/:slug/:topic_id/pin
  def pin
    NestedTopic::TogglePin.call(service_params.deep_merge(params: { topic_id: @topic.id })) do
      on_success { |nested_topic:| render json: { pinned_post_ids: nested_topic.pinned_post_ids } }
      on_failed_contract { raise Discourse::NotFound }
      on_model_not_found(:topic) { raise Discourse::NotFound }
      on_model_not_found(:post) { raise Discourse::NotFound }
      on_failed_policy(:staff_can_edit) { raise Discourse::InvalidAccess }
      on_failed_policy(:post_is_root) { raise Discourse::InvalidParameters.new(:post_id) }
      on_failed_policy(:within_pin_limit) { raise Discourse::InvalidParameters.new(:post_id) }
      on_failure { raise Discourse::InvalidParameters }
    end
  end

  # PUT /n/:slug/:topic_id/toggle
  def toggle
    NestedTopic::Toggle.call(service_params.deep_merge(params: { topic_id: @topic.id })) do
      on_success { |params:| render json: { is_nested_view: params.enabled } }
      on_model_not_found(:topic) { raise Discourse::NotFound }
      on_failed_policy(:staff_can_edit) { raise Discourse::InvalidAccess }
      on_failure { raise Discourse::InvalidParameters }
    end
  end

  private

  def build_initial_roots_response(sort)
    roots = loader.root_posts_scope(sort).offset(0).limit(NestedReplies::TreeLoader::ROOTS_PER_PAGE)
    roots = loader.load_posts_for_tree(roots).to_a
    has_more_roots = roots.size == NestedReplies::TreeLoader::ROOTS_PER_PAGE

    pinned_post_ids = @topic.nested_topic&.pinned_post_ids.presence

    if pinned_post_ids.present?
      pinned_in_page = []
      pinned_missing_ids = []

      pinned_post_ids.each do |pid|
        idx = roots.index { |p| p.id == pid }
        if idx
          pinned_in_page << roots.delete_at(idx) if roots[idx].deleted_at.nil?
        else
          pinned_missing_ids << pid
        end
      end

      if pinned_missing_ids.present?
        fetched =
          loader.load_posts_for_tree(
            loader.apply_visibility(@topic.posts.where(id: pinned_missing_ids)),
          ).index_by(&:id)
        pinned_missing_ids.each do |pid|
          post = fetched[pid]
          pinned_in_page << post if post && post.deleted_at.nil?
        end
      end

      roots = pinned_in_page + roots
    end

    tree_data =
      loader.batch_preload_tree(roots, sort, max_depth: NestedReplies::TreeLoader::PRELOAD_DEPTH)
    children_map = tree_data[:children_map]

    all_posts = [loader.op_post] + tree_data[:all_posts]

    preloader.prepare(all_posts)
    reply_counts = loader.direct_reply_counts(all_posts.map(&:post_number))
    descendant_counts = loader.total_descendant_counts(all_posts.map(&:id))

    result = {
      roots:
        roots.map do |root|
          serializer.serialize_tree(root, children_map, reply_counts, descendant_counts)
        end,
      has_more_roots: has_more_roots,
      page: 0,
      topic: serializer.serialize_topic,
      op_post: serializer.serialize_post(loader.op_post, reply_counts, descendant_counts),
      sort: sort,
      message_bus_last_id: @topic_view.message_bus_last_id,
    }
    result[:pinned_post_ids] = pinned_post_ids if pinned_post_ids.present?
    result
  end

  def build_context_response(target_post_number, sort, context_depth: nil)
    max_depth = loader.configured_max_depth

    target = @topic.posts.find_by(post_number: target_post_number)
    raise Discourse::NotFound unless target
    raise Discourse::NotFound if loader.visible_post_types.exclude?(target.post_type)

    ancestors = []
    ancestors_truncated = false
    unless context_depth == 0 || target.reply_to_post_number.blank? ||
             target.reply_to_post_number == 1
      depth_limit = context_depth || max_depth

      ancestor_rows =
        NestedReplies.walk_ancestors(
          topic_id: @topic.id,
          start_post_number: target.reply_to_post_number,
          limit: depth_limit,
          exclude_deleted: false,
          stop_at_op: true,
        )
      ancestor_post_numbers = ancestor_rows.sort_by { |a| -a.depth }.map(&:post_number)

      if ancestor_post_numbers.present?
        scope = @topic.posts.where(post_number: ancestor_post_numbers)
        scope = loader.apply_visibility(scope)
        loaded = loader.load_posts_for_tree(scope).to_a.index_by(&:post_number)
        ancestors = ancestor_post_numbers.filter_map { |pn| loaded[pn] }
      end

      if ancestors.present?
        top_ancestor = ancestors.first
        ancestors_truncated =
          top_ancestor.reply_to_post_number.present? && top_ancestor.reply_to_post_number != 1
      end
    end

    siblings_map = {}
    unless context_depth == 0 || ancestors.empty?
      siblings_map = loader.batch_load_siblings(ancestors, sort)
    end

    tree_data =
      loader.batch_preload_tree([target], sort, max_depth: NestedReplies::TreeLoader::PRELOAD_DEPTH)
    children_map = tree_data[:children_map]

    all_posts =
      [loader.op_post, target] + ancestors + siblings_map.values.flatten + tree_data[:all_posts]
    all_posts.uniq!(&:id)

    preloader.prepare(all_posts)
    reply_counts = loader.direct_reply_counts(all_posts.map(&:post_number))
    descendant_counts = loader.total_descendant_counts(all_posts.map(&:id))

    {
      topic: serializer.serialize_topic,
      op_post: serializer.serialize_post(loader.op_post, reply_counts, descendant_counts),
      ancestor_chain:
        ancestors.map { |a| serializer.serialize_post(a, reply_counts, descendant_counts) },
      ancestors_truncated: ancestors_truncated,
      siblings:
        siblings_map.transform_values do |posts|
          posts.map { |p| serializer.serialize_post(p, reply_counts, descendant_counts) }
        end,
      target_post: serializer.serialize_tree(target, children_map, reply_counts, descendant_counts),
      message_bus_last_id: @topic_view.message_bus_last_id,
    }
  end

  def ensure_nested_replies_enabled
    raise Discourse::NotFound unless SiteSetting.nested_replies_enabled
  end

  def ensure_not_pm
    if @topic.private_message?
      url = "/t/#{@topic.slug}/#{@topic.id}"
      post_number = params[:post_number].to_i
      url << "/#{post_number}" if post_number > 0
      redirect_to url, status: :found
    end
  end

  def find_topic
    topic_id = params[:topic_id].to_i
    @topic_view =
      TopicView.new(topic_id, current_user, skip_custom_fields: true, skip_post_loading: true)
    @topic = @topic_view.topic
  end

  def validated_sort
    sort = params[:sort].to_s.downcase
    NestedReplies::Sort.valid?(sort) ? sort : SiteSetting.nested_replies_default_sort
  end

  def loader
    @loader ||= NestedReplies::TreeLoader.new(topic: @topic, guardian: guardian)
  end

  def preloader
    @preloader ||=
      NestedReplies::PostPreloader.new(
        topic_view: @topic_view,
        topic: @topic,
        current_user: current_user,
        guardian: guardian,
      )
  end

  def serializer
    @serializer ||=
      NestedReplies::PostTreeSerializer.new(
        topic: @topic,
        topic_view: @topic_view,
        guardian: guardian,
      )
  end
end
