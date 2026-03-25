# frozen_string_literal: true

class NestedTopicsController < ApplicationController
  before_action :ensure_nested_replies_enabled
  before_action :find_topic, except: %i[respond]

  def respond
    render
  end

  # GET /n/:slug/:topic_id/roots
  # On page 0 (initial load), includes topic metadata, OP post, sort, and message_bus_last_id.
  # On subsequent pages, returns only roots for pagination.
  def roots
    sort = validated_sort
    page = [params[:page].to_i, 0].max
    initial_load = page == 0

    roots =
      loader
        .root_posts_scope(sort)
        .offset(page * NestedReplies::TreeLoader::ROOTS_PER_PAGE)
        .limit(NestedReplies::TreeLoader::ROOTS_PER_PAGE)
    roots = loader.load_posts_for_tree(roots).to_a

    # Pin: ensure the pinned root appears first on initial load
    pinned_post_number = (@topic.nested_topic&.pinned_post_number if initial_load)

    if pinned_post_number.present?
      pinned_index = roots.index { |p| p.post_number == pinned_post_number }
      if pinned_index
        pinned_post = roots[pinned_index]
        roots.unshift(roots.delete_at(pinned_index)) if pinned_post.deleted_at.nil?
      else
        pinned_post =
          loader.load_posts_for_tree(
            loader.apply_visibility(@topic.posts.where(post_number: pinned_post_number)),
          ).first
        roots.unshift(pinned_post) if pinned_post && pinned_post.deleted_at.nil?
      end
    end

    tree_data =
      loader.batch_preload_tree(roots, sort, max_depth: NestedReplies::TreeLoader::PRELOAD_DEPTH)
    children_map = tree_data[:children_map]

    all_posts = initial_load ? [loader.op_post] + tree_data[:all_posts] : tree_data[:all_posts].dup

    preloader.prepare(all_posts)
    reply_counts = loader.direct_reply_counts(all_posts.map(&:post_number))
    descendant_counts = loader.total_descendant_counts(all_posts.map(&:id))

    result = {
      roots:
        roots.map do |root|
          serializer.serialize_tree(root, children_map, reply_counts, descendant_counts)
        end,
      has_more_roots: roots.size == NestedReplies::TreeLoader::ROOTS_PER_PAGE,
      page: page,
    }

    if initial_load
      result[:topic] = serializer.serialize_topic
      result[:op_post] = serializer.serialize_post(loader.op_post, reply_counts, descendant_counts)
      result[:sort] = sort
      result[:message_bus_last_id] = @topic_view.message_bus_last_id
      result[:pinned_post_number] = pinned_post_number if pinned_post_number.present?
    end

    render json: result
  end

  # GET /n/:slug/:topic_id/children/:post_number
  def children
    parent_post_number = params[:post_number].to_i
    sort = validated_sort
    page = [params[:page].to_i, 0].max
    depth = [params[:depth].to_i, 1].max

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

  # GET /n/:slug/:topic_id/context/:post_number
  # Optional param: context (integer) -- controls ancestor depth.
  #   nil/absent = windowed ancestor chain capped at max_depth (deep-links, notifications)
  #   0 = no ancestors, target at depth 0 ("Continue this thread")
  def context
    target_post_number = params[:post_number].to_i
    sort = validated_sort
    context_depth = params[:context]&.to_i # nil = windowed chain, 0 = no ancestors
    max_depth = loader.configured_max_depth

    target = @topic.posts.find_by(post_number: target_post_number)
    raise Discourse::NotFound unless target

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

    render json: {
             topic: serializer.serialize_topic,
             op_post: serializer.serialize_post(loader.op_post, reply_counts, descendant_counts),
             ancestor_chain:
               ancestors.map { |a| serializer.serialize_post(a, reply_counts, descendant_counts) },
             ancestors_truncated: ancestors_truncated,
             siblings:
               siblings_map.transform_values { |posts|
                 posts.map { |p| serializer.serialize_post(p, reply_counts, descendant_counts) }
               },
             target_post:
               serializer.serialize_tree(target, children_map, reply_counts, descendant_counts),
             message_bus_last_id: @topic_view.message_bus_last_id,
           }
  end

  # PUT /n/:slug/:topic_id/pin
  def pin
    guardian.ensure_can_edit!(@topic)
    raise Discourse::InvalidAccess unless guardian.is_staff?

    post_number = params[:post_number].presence&.to_i

    if post_number
      post = @topic.posts.where(post_number: post_number).first
      raise Discourse::NotFound unless post
      if post.reply_to_post_number.present? && post.reply_to_post_number != 1
        raise Discourse::InvalidParameters.new(:post_number)
      end
    end

    nested_topic = @topic.nested_topic
    raise Discourse::NotFound unless nested_topic
    nested_topic.update!(pinned_post_number: post_number)

    render json: { pinned_post_number: post_number }
  end

  # PUT /n/:slug/:topic_id/toggle
  def toggle
    guardian.ensure_can_edit!(@topic)
    raise Discourse::InvalidAccess unless guardian.is_staff?

    enabled = params[:enabled].to_s == "true"

    if enabled
      @topic.create_nested_topic! unless @topic.nested_topic
    else
      @topic.nested_topic&.destroy!
    end

    render json: { is_nested_view: enabled }
  end

  private

  def ensure_nested_replies_enabled
    raise Discourse::NotFound unless SiteSetting.nested_replies_enabled
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
