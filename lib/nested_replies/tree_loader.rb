# frozen_string_literal: true

module NestedReplies
  class TreeLoader
    PRELOAD_DEPTH = 3
    ROOTS_PER_PAGE = 20
    CHILDREN_PER_PAGE = 50
    PRELOAD_CHILDREN_PER_PARENT = 3
    SIBLINGS_PER_ANCESTOR = 5

    POST_INCLUDES = [
      { user: %i[primary_group flair_group] },
      :reply_to_user,
      :deleted_by,
      :incoming_email,
      :image_upload,
    ].freeze

    attr_reader :topic, :guardian

    def initialize(topic:, guardian:)
      @topic = topic
      @guardian = guardian
    end

    def visible_post_types
      @visible_post_types ||=
        begin
          types = [Post.types[:regular], Post.types[:moderator_action]]
          types << Post.types[:whisper] if guardian.user&.whisperer?
          types
        end
    end

    def op_post
      @op_post ||= load_posts_for_tree(topic.posts.where(post_number: 1)).first
    end

    def root_posts_scope(sort)
      scope =
        topic
          .posts
          .where("reply_to_post_number IS NULL OR reply_to_post_number = 1")
          .where(post_number: 2..) # exclude OP itself
      scope = apply_visibility(scope)
      NestedReplies::Sort.apply(scope, sort)
    end

    def load_posts_for_tree(scope)
      scope = scope.includes(*POST_INCLUDES)
      scope = scope.includes(:localizations) if SiteSetting.content_localization_enabled
      scope = scope.includes({ user: :user_status }) if SiteSetting.enable_user_status
      scope
    end

    def apply_visibility(scope)
      scope = scope.unscope(where: :deleted_at)
      scope = scope.where(post_type: visible_post_types)
      scope
    end

    def batch_preload_tree(starting_posts, sort, max_depth:)
      all_posts = starting_posts.dup
      children_map = {}

      current_level = starting_posts
      max_depth.times do |depth|
        break if current_level.empty?

        parent_numbers = current_level.map(&:post_number)
        last_level = (depth + 1 >= max_depth) || (depth + 1 >= configured_max_depth)

        order_expr = NestedReplies::Sort.sql_order_expression(sort)
        child_ids =
          DB.query_single(
            <<~SQL,
              SELECT id FROM (
                SELECT id,
                       ROW_NUMBER() OVER (PARTITION BY reply_to_post_number ORDER BY #{order_expr}) AS rn
                FROM posts
                WHERE topic_id = :topic_id
                  AND reply_to_post_number IN (:parent_numbers)
                  AND post_type IN (:post_types)
                  AND post_number > 1
              ) ranked
              WHERE rn <= :limit
            SQL
            topic_id: topic.id,
            parent_numbers: parent_numbers,
            limit: PRELOAD_CHILDREN_PER_PARENT,
            post_types: visible_post_types,
          )

        break if child_ids.empty?

        all_children = load_posts_for_tree(topic.posts.with_deleted.where(id: child_ids)).to_a

        next_level = []
        all_children
          .group_by(&:reply_to_post_number)
          .each do |parent_number, child_posts|
            sorted = NestedReplies::Sort.sort_in_memory(child_posts, sort)
            children_map[parent_number] = sorted
            all_posts.concat(sorted)
            next_level.concat(sorted) unless last_level
          end

        current_level = next_level
      end

      { children_map: children_map, all_posts: all_posts }
    end

    def batch_load_siblings(ancestors, sort)
      root_ancestors, child_ancestors = ancestors.partition { |a| a.reply_to_post_number.nil? }

      siblings_map = {}

      if child_ancestors.present?
        parent_numbers = child_ancestors.map(&:reply_to_post_number).uniq

        order_expr = NestedReplies::Sort.sql_order_expression(sort)

        visibility_conditions = +"post_type IN (:post_types) AND post_number > 1"
        sql_params = {
          topic_id: topic.id,
          parent_numbers: parent_numbers,
          limit: SIBLINGS_PER_ANCESTOR,
          post_types: visible_post_types,
        }

        sibling_ids = DB.query_single(<<~SQL, **sql_params)
            SELECT id FROM (
              SELECT id, reply_to_post_number,
                     ROW_NUMBER() OVER (PARTITION BY reply_to_post_number ORDER BY #{order_expr}) AS rn
              FROM posts
              WHERE topic_id = :topic_id
                AND reply_to_post_number IN (:parent_numbers)
                AND #{visibility_conditions}
            ) ranked
            WHERE rn <= :limit
          SQL

        if sibling_ids.present?
          loaded_siblings =
            load_posts_for_tree(topic.posts.with_deleted.where(id: sibling_ids)).to_a
          grouped = loaded_siblings.group_by(&:reply_to_post_number)

          grouped.transform_values! { |posts| NestedReplies::Sort.sort_in_memory(posts, sort) }

          child_ancestors.each do |ancestor|
            siblings_map[ancestor.post_number] = grouped[ancestor.reply_to_post_number] || []
          end
        end
      end

      if root_ancestors.present?
        root_siblings =
          load_posts_for_tree(root_posts_scope(sort).limit(SIBLINGS_PER_ANCESTOR)).to_a
        root_ancestors.each { |ancestor| siblings_map[ancestor.post_number] = root_siblings }
      end

      siblings_map
    end

    def flat_descendants_scope(parent_post_number, sort:, offset: 0, limit: CHILDREN_PER_PAGE)
      post_types = visible_post_types
      order_expr = NestedReplies::Sort.sql_order_expression(sort)

      descendant_post_numbers =
        DB.query_single(
          <<~SQL,
          WITH RECURSIVE descendants AS (
            SELECT post_number, 1 AS depth
            FROM posts
            WHERE topic_id = :topic_id
              AND reply_to_post_number = :parent_number
              AND post_number > 1
            UNION ALL
            SELECT p.post_number, d.depth + 1
            FROM posts p
            JOIN descendants d ON p.reply_to_post_number = d.post_number
            WHERE p.topic_id = :topic_id
              AND p.post_number > 1
              AND d.depth < :max_cte_depth
          )
          SELECT d.post_number
          FROM descendants d
          JOIN posts p ON p.post_number = d.post_number AND p.topic_id = :topic_id
          WHERE p.post_type IN (:post_types)
          ORDER BY #{order_expr}
          OFFSET :offset
          LIMIT :limit
        SQL
          topic_id: topic.id,
          parent_number: parent_post_number,
          post_types: post_types,
          offset: offset,
          limit: limit,
          max_cte_depth: 500,
        )

      scope =
        topic.posts.with_deleted.where(post_number: descendant_post_numbers).where(post_number: 2..)
      NestedReplies::Sort.apply(scope, sort)
    end

    def configured_max_depth
      SiteSetting.nested_replies_max_depth
    end

    def direct_reply_counts(post_numbers)
      return {} if post_numbers.empty?

      Post
        .with_deleted
        .where(topic_id: topic.id)
        .where(reply_to_post_number: post_numbers)
        .where(post_type: visible_post_types)
        .group(:reply_to_post_number)
        .count
    end

    def total_descendant_counts(post_ids)
      return {} if post_ids.empty?

      if guardian.user&.whisperer?
        NestedViewPostStat
          .where(post_id: post_ids.uniq)
          .pluck(:post_id, :total_descendant_count)
          .to_h
      else
        NestedViewPostStat
          .where(post_id: post_ids.uniq)
          .pluck(:post_id, Arel.sql("total_descendant_count - whisper_total_descendant_count"))
          .to_h
      end
    end
  end
end
