# frozen_string_literal: true

class NestedTopic::ListChildren
  include Service::Base

  params do
    attribute :parent_post_number, :integer
    attribute :sort, :string
    attribute :page, :integer
    attribute :depth, :integer

    validates :parent_post_number, presence: true
    validates :sort, presence: true
    validates :page, presence: true, numericality: { greater_than_or_equal_to: 0 }
    validates :depth, presence: true, numericality: { greater_than_or_equal_to: 1 }
  end

  model :loader, :build_loader
  model :preloader, :build_preloader
  model :serializer, :build_serializer
  step :load_children
  only_if(:nested) { step :expand_reply_trees }
  step :prepare_posts
  step :serialize_children

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

  def nested(params:, loader:)
    !flattened?(params, loader)
  end

  def load_children(params:, loader:, topic_view:)
    context[:flatten] = flattened?(params, loader)
    per_page = NestedReplies::TreeLoader::CHILDREN_PER_PAGE

    children_scope = nil
    children_posts = nil

    if context[:flatten]
      children_scope =
        loader.flat_descendants_scope(
          params.parent_post_number,
          sort: params.sort,
          offset: params.page * per_page,
          limit: per_page,
        )
    elsif params.sort == "hot"
      child_ids =
        loader.hot_sorted_child_ids(
          params.parent_post_number,
          offset: params.page * per_page,
          limit: per_page,
        )
      children_posts =
        loader.load_posts_for_tree(topic_view.topic.posts.with_deleted.where(id: child_ids)).to_a
      hot_scores = loader.hot_scores_for_posts(children_posts)
      children_posts =
        NestedReplies::Sort.sort_in_memory(children_posts, params.sort, hot_scores: hot_scores)
    else
      children_scope =
        topic_view
          .topic
          .posts
          .where(reply_to_post_number: params.parent_post_number)
          .where(post_number: 2..)
      children_scope = loader.apply_visibility(children_scope)
      children_scope = NestedReplies::Sort.apply(children_scope, params.sort)
      children_scope = children_scope.offset(params.page * per_page).limit(per_page)
    end

    context[:children_posts] = children_posts || loader.load_posts_for_tree(children_scope).to_a
    context[:children_map] = {}
    context[:all_posts] = context[:children_posts]
  end

  def expand_reply_trees(params:, loader:, children_posts:)
    remaining_depth =
      if params.depth < loader.configured_max_depth
        [NestedReplies::TreeLoader::PRELOAD_DEPTH, loader.configured_max_depth - params.depth].min
      else
        0
      end
    tree_data = loader.batch_preload_tree(children_posts, params.sort, max_depth: remaining_depth)
    context[:children_map] = tree_data[:children_map]
    context[:all_posts] = tree_data[:all_posts]
  end

  def prepare_posts(loader:, preloader:, all_posts:)
    preloader.prepare(all_posts)
    counts = loader.tree_counts(all_posts)
    context[:reply_counts] = counts[:reply_counts]
    context[:descendant_counts] = counts[:descendant_counts]
  end

  def serialize_children(
    params:,
    children_posts:,
    children_map:,
    reply_counts:,
    descendant_counts:,
    serializer:,
    flatten:
  )
    context[:response] = {
      children:
        children_posts.map do |child|
          if flatten
            serializer.serialize_post(child, reply_counts, descendant_counts).merge(children: [])
          else
            serializer.serialize_tree(child, children_map, reply_counts, descendant_counts)
          end
        end,
      has_more: children_posts.size == NestedReplies::TreeLoader::CHILDREN_PER_PAGE,
      page: params.page,
    }
  end

  def flattened?(params, loader)
    SiteSetting.nested_replies_cap_nesting_depth && params.depth >= loader.configured_max_depth
  end
end
