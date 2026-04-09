# frozen_string_literal: true

class NestedTopic::ListRoots
  include Service::Base

  params do
    attribute :sort, :string
    attribute :page, :integer

    validates :sort, presence: true
    validates :page, presence: true, numericality: { greater_than_or_equal_to: 0 }
  end

  model :loader, :build_loader
  model :preloader, :build_preloader
  model :serializer, :build_serializer
  step :load_roots
  only_if(:initial_page) { step :promote_pinned_roots }
  step :expand_reply_trees
  step :prepare_posts
  step :serialize_roots
  only_if(:initial_page) { step :enrich_with_topic_metadata }

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

  def initial_page(params:)
    params.page == 0
  end

  def load_roots(params:, loader:, topic_view:)
    pinned_post_ids = topic_view.topic.nested_topic&.pinned_post_ids.presence
    scope = loader.root_posts_scope(params.sort)
    scope = scope.where.not(id: pinned_post_ids) if pinned_post_ids.present?
    roots =
      scope.offset(params.page * NestedReplies::TreeLoader::ROOTS_PER_PAGE).limit(
        NestedReplies::TreeLoader::ROOTS_PER_PAGE,
      )
    context[:roots] = loader.load_posts_for_tree(roots).to_a
    context[:has_more_roots] = context[:roots].size == NestedReplies::TreeLoader::ROOTS_PER_PAGE
  end

  def promote_pinned_roots(loader:, topic_view:, roots:)
    pinned_post_ids = topic_view.topic.nested_topic&.pinned_post_ids.presence
    context[:pinned_post_ids] = pinned_post_ids
    context[:roots] = loader.promote_pinned_roots(roots, pinned_post_ids)
  end

  def expand_reply_trees(loader:, params:, roots:)
    tree_data =
      loader.batch_preload_tree(
        roots,
        params.sort,
        max_depth: NestedReplies::TreeLoader::PRELOAD_DEPTH,
      )
    context[:children_map] = tree_data[:children_map]
    context[:all_posts] = tree_data[:all_posts]
  end

  def prepare_posts(params:, loader:, preloader:, all_posts:)
    posts = params.page == 0 ? [loader.op_post] + all_posts : all_posts.dup

    preloader.prepare(posts)
    context[:reply_counts] = loader.direct_reply_counts(posts.map(&:post_number))
    context[:descendant_counts] = loader.total_descendant_counts(posts.map(&:id))
  end

  def serialize_roots(
    params:,
    roots:,
    has_more_roots:,
    children_map:,
    reply_counts:,
    descendant_counts:,
    serializer:
  )
    context[:response] = {
      roots:
        roots.map do |root|
          serializer.serialize_tree(root, children_map, reply_counts, descendant_counts)
        end,
      has_more_roots: has_more_roots,
      page: params.page,
    }
  end

  def enrich_with_topic_metadata(
    params:,
    serializer:,
    loader:,
    topic_view:,
    reply_counts:,
    descendant_counts:,
    response:,
    pinned_post_ids:
  )
    response[:topic] = serializer.serialize_topic
    response[:op_post] = serializer.serialize_post(loader.op_post, reply_counts, descendant_counts)
    response[:sort] = params.sort
    response[:message_bus_last_id] = topic_view.message_bus_last_id
    response[:pinned_post_ids] = pinned_post_ids if pinned_post_ids.present?
  end
end
