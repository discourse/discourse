# frozen_string_literal: true

class NestedTopic::ShowContext
  include Service::Base

  params do
    attribute :target_post_number, :integer
    attribute :sort, :string
    attribute :context_depth, :integer

    validates :target_post_number, presence: true
    validates :sort, presence: true
    validates :context_depth,
              numericality: {
                greater_than_or_equal_to: 0,
                less_than_or_equal_to: 100,
              },
              allow_nil: true
  end

  model :loader, :build_loader
  model :preloader, :build_preloader
  model :serializer, :build_serializer
  model :target_post
  step :initialize_ancestor_data
  only_if(:should_walk_ancestors) do
    step :walk_ancestors
    only_if(:ancestors_found) { step :load_siblings }
  end
  step :expand_reply_trees
  step :prepare_posts
  step :serialize_context

  private

  def build_loader(topic_view:, guardian:)
    NestedReplies::TreeLoader.new(topic: topic_view.topic, guardian: guardian)
  end

  def build_preloader(topic_view:, guardian:)
    NestedReplies::PostPreloader.new(
      topic_view: topic_view,
      topic: topic_view.topic,
      current_user: guardian.user,
      guardian: guardian,
    )
  end

  def build_serializer(topic_view:, guardian:)
    NestedReplies::PostTreeSerializer.new(
      topic: topic_view.topic,
      topic_view: topic_view,
      guardian: guardian,
    )
  end

  def fetch_target_post(params:, topic_view:, loader:)
    # apply_visibility unscopes deleted_at and filters by visible_post_types,
    # matching the rest of the tree-loading code. Without this, a link to a
    # since-soft-deleted post (e.g. a stale last_read_post_number from
    # suggested topics) would 404 even though the deleted_post_placeholder
    # path in the serializer is designed to render it.
    loader.apply_visibility(topic_view.topic.posts).find_by(post_number: params.target_post_number)
  end

  def should_walk_ancestors(params:, target_post:)
    return if params.context_depth == 0
    return if target_post.reply_to_post_number.blank?
    return if target_post.reply_to_post_number == 1
    true
  end

  def initialize_ancestor_data
    context[:ancestors] = []
    context[:ancestors_truncated] = false
    context[:siblings_map] = {}
  end

  def walk_ancestors(params:, target_post:, topic_view:, loader:)
    depth_limit = params.context_depth || loader.configured_max_depth

    ancestor_rows =
      NestedReplies.walk_ancestors(
        topic_id: topic_view.topic.id,
        start_post_number: target_post.reply_to_post_number,
        limit: depth_limit,
        exclude_deleted: false,
        stop_at_op: true,
      )
    ancestor_post_numbers = ancestor_rows.sort_by { |a| -a.depth }.map(&:post_number)

    if ancestor_post_numbers.present?
      scope = topic_view.topic.posts.where(post_number: ancestor_post_numbers)
      scope = loader.apply_visibility(scope)
      loaded = loader.load_posts_for_tree(scope).to_a.index_by(&:post_number)
      context[:ancestors] = ancestor_post_numbers.filter_map { |pn| loaded[pn] }
    end

    if context[:ancestors].present?
      top_ancestor = context[:ancestors].first
      context[:ancestors_truncated] = top_ancestor.reply_to_post_number.present? &&
        top_ancestor.reply_to_post_number != 1
    end
  end

  def ancestors_found(ancestors:)
    ancestors.present?
  end

  def load_siblings(params:, loader:, ancestors:)
    context[:siblings_map] = loader.batch_load_siblings(ancestors, params.sort)
  end

  def expand_reply_trees(params:, loader:, target_post:)
    tree_data =
      loader.batch_preload_tree(
        [target_post],
        params.sort,
        max_depth: NestedReplies::TreeLoader::PRELOAD_DEPTH,
      )
    context[:children_map] = tree_data[:children_map]
    context[:tree_posts] = tree_data[:all_posts]
  end

  def prepare_posts(loader:, preloader:, target_post:, ancestors:, siblings_map:, tree_posts:)
    all_posts = [loader.op_post, target_post] + ancestors + siblings_map.values.flatten + tree_posts
    all_posts.uniq!(&:id)

    preloader.prepare(all_posts)
    context[:reply_counts] = loader.direct_reply_counts(all_posts.map(&:post_number))
    context[:descendant_counts] = loader.total_descendant_counts(all_posts.map(&:id))
  end

  def serialize_context(
    loader:,
    serializer:,
    target_post:,
    topic_view:,
    ancestors:,
    ancestors_truncated:,
    siblings_map:,
    children_map:,
    reply_counts:,
    descendant_counts:
  )
    context[:response] = {
      topic: serializer.serialize_topic,
      op_post: serializer.serialize_post(loader.op_post, reply_counts, descendant_counts),
      ancestor_chain:
        ancestors.map { |a| serializer.serialize_post(a, reply_counts, descendant_counts) },
      ancestors_truncated: ancestors_truncated,
      siblings:
        siblings_map.transform_values do |posts|
          posts.map { |p| serializer.serialize_post(p, reply_counts, descendant_counts) }
        end,
      target_post:
        serializer.serialize_tree(target_post, children_map, reply_counts, descendant_counts),
      message_bus_last_id: topic_view.message_bus_last_id,
    }
  end
end
