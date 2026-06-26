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
      @op_post ||= load_posts_for_tree(apply_visibility(topic.posts.where(post_number: 1))).first
    end

    def root_posts_scope(sort)
      scope =
        topic
          .posts
          .where("posts.reply_to_post_number IS NULL OR posts.reply_to_post_number = 1")
          .where(post_number: 2..) # exclude OP itself
      scope = apply_visibility(scope)
      NestedReplies::Sort.apply(scope, sort)
    end

    def promote_pinned_roots(roots, pinned_post_ids)
      return roots if pinned_post_ids.blank?

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
          load_posts_for_tree(apply_visibility(topic.posts.where(id: pinned_missing_ids))).index_by(
            &:id
          )
        pinned_missing_ids.each do |pid|
          post = fetched[pid]
          pinned_in_page << post if post && post.deleted_at.nil?
        end
      end

      pinned_in_page + roots
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
      if guardian.user&.whisperer?
        scope =
          scope.where(
            "post_type != :whisper OR action_code IS NULL OR action_code = ''",
            whisper: Post.types[:whisper],
          )
      end
      scope
    end

    def visibility_sql(posts_table: "posts")
      sql = +"#{posts_table}.post_type IN (:post_types)"
      if guardian.user&.whisperer?
        sql << " AND (#{posts_table}.post_type != :whisper OR #{posts_table}.action_code IS NULL OR #{posts_table}.action_code = '')"
      end
      sql
    end

    def batch_preload_tree(starting_posts, sort, max_depth:)
      return batch_preload_hot_tree(starting_posts, max_depth: max_depth) if sort == "hot"

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
                SELECT posts.id,
                       ROW_NUMBER() OVER (PARTITION BY posts.reply_to_post_number ORDER BY #{order_expr}) AS rn
                FROM posts
                WHERE posts.topic_id = :topic_id
                  AND posts.reply_to_post_number IN (:parent_numbers)
                  AND #{visibility_sql}
                  AND posts.post_number > 1
              ) ranked
              WHERE rn <= :limit
            SQL
            topic_id: topic.id,
            parent_numbers: parent_numbers,
            limit: PRELOAD_CHILDREN_PER_PARENT,
            post_types: visible_post_types,
            whisper: Post.types[:whisper],
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

    def batch_preload_hot_tree(starting_posts, max_depth:)
      all_posts = starting_posts.dup
      children_map = {}
      max_preload_depth = [max_depth, configured_max_depth].min
      post_budget = hot_preload_post_budget
      per_root_budget = hot_preload_per_root_budget
      children_per_parent = hot_preload_children_per_parent

      if starting_posts.empty? || max_preload_depth <= 0 || post_budget <= 0
        return { children_map: children_map, all_posts: all_posts }
      end

      root_scores = hot_scores_for_posts(starting_posts)
      candidates =
        starting_posts.map do |post|
          thread_hot_score, hot_score, relative_thread_hot_score, relative_hot_score =
            NestedReplies::Sort.hot_score_values(post, root_scores[post.id])
          {
            post: post,
            branch_post_number: post.post_number,
            depth: 0,
            priority: hot_preload_priority(thread_hot_score, relative_thread_hot_score, 0),
            thread_hot_score: thread_hot_score,
            hot_score: hot_score,
            relative_thread_hot_score: relative_thread_hot_score,
            relative_hot_score: relative_hot_score,
          }
        end

      preloaded_count = 0
      branch_preloaded_counts = Hash.new(0)
      expanded_parent_numbers = {}

      while candidates.any? && preloaded_count < post_budget
        candidates.sort_by! do |candidate|
          [
            -candidate[:priority],
            -candidate[:relative_thread_hot_score],
            -candidate[:thread_hot_score],
            -candidate[:hot_score],
            candidate[:post].post_number,
          ]
        end

        candidate = candidates.shift
        parent_post = candidate[:post]
        branch_post_number = candidate[:branch_post_number]

        next if candidate[:depth] >= max_preload_depth
        next if expanded_parent_numbers[parent_post.post_number]
        next if branch_preloaded_counts[branch_post_number] >= per_root_budget

        remaining_total_budget = post_budget - preloaded_count
        remaining_branch_budget = per_root_budget - branch_preloaded_counts[branch_post_number]
        limit = [children_per_parent, remaining_total_budget, remaining_branch_budget].min
        next if limit <= 0

        expanded_parent_numbers[parent_post.post_number] = true
        child_data = load_hot_preload_children(parent_post.post_number, limit: limit)
        child_posts = child_data[:posts]
        next if child_posts.empty?

        children_map[parent_post.post_number] = child_posts
        all_posts.concat(child_posts)
        preloaded_count += child_posts.size
        branch_preloaded_counts[branch_post_number] += child_posts.size

        child_depth = candidate[:depth] + 1
        next if child_depth >= max_preload_depth

        add_hot_preload_candidates(
          candidates,
          child_posts,
          child_data[:hot_scores],
          branch_post_number,
          child_depth,
        )
      end

      { children_map: children_map, all_posts: all_posts }
    end

    def hot_preload_post_budget
      SiteSetting.nested_replies_hot_preload_post_budget.to_i
    end

    def hot_preload_per_root_budget
      SiteSetting.nested_replies_hot_preload_per_root_budget.to_i
    end

    def hot_preload_children_per_parent
      SiteSetting.nested_replies_hot_preload_children_per_parent.to_i
    end

    def hot_preload_min_relative_score
      SiteSetting.nested_replies_hot_preload_min_relative_score.to_f
    end

    def hot_preload_depth_decay
      SiteSetting.nested_replies_hot_preload_depth_decay.to_f
    end

    def hot_preload_priority(thread_hot_score, relative_thread_hot_score, depth)
      priority_score =
        relative_thread_hot_score.to_f.positive? ? relative_thread_hot_score : thread_hot_score
      priority_score * (hot_preload_depth_decay**depth)
    end

    def load_hot_preload_children(parent_post_number, limit:)
      rows =
        DB.query(
          <<~SQL,
            SELECT posts.id,
                   COALESCE(nested_view_post_stats.thread_hot_score, 0) AS thread_hot_score,
                   COALESCE(nested_view_post_stats.hot_score, 0) AS hot_score,
                   COALESCE(nested_view_post_stats.relative_thread_hot_score, 0) AS relative_thread_hot_score,
                   COALESCE(nested_view_post_stats.relative_hot_score, 0) AS relative_hot_score
            FROM posts
            #{NestedReplies::Sort.hot_score_join_sql}
            WHERE posts.topic_id = :topic_id
              AND posts.reply_to_post_number = :parent_post_number
              AND #{visibility_sql}
              AND posts.post_number > 1
            ORDER BY #{NestedReplies::Sort.sql_order_expression("hot")}
            LIMIT :limit
          SQL
          topic_id: topic.id,
          parent_post_number: parent_post_number,
          post_types: visible_post_types,
          whisper: Post.types[:whisper],
          limit: limit,
        )

      return { posts: [], hot_scores: {} } if rows.empty?

      post_ids = rows.map(&:id)
      hot_scores =
        rows.to_h do |row|
          [
            row.id,
            [
              row.thread_hot_score.to_f,
              row.hot_score.to_f,
              row.relative_thread_hot_score.to_f,
              row.relative_hot_score.to_f,
            ],
          ]
        end
      posts_by_id =
        load_posts_for_tree(topic.posts.with_deleted.where(id: post_ids)).to_a.index_by(&:id)
      child_posts = post_ids.filter_map { |post_id| posts_by_id[post_id] }

      {
        posts: NestedReplies::Sort.sort_in_memory(child_posts, "hot", hot_scores: hot_scores),
        hot_scores: hot_scores,
      }
    end

    def add_hot_preload_candidates(candidates, child_posts, hot_scores, branch_post_number, depth)
      scored_children =
        child_posts.map do |post|
          thread_hot_score, hot_score, relative_thread_hot_score, relative_hot_score =
            NestedReplies::Sort.hot_score_values(post, hot_scores[post.id])
          {
            post: post,
            thread_hot_score: thread_hot_score,
            hot_score: hot_score,
            relative_thread_hot_score: relative_thread_hot_score,
            relative_hot_score: relative_hot_score,
          }
        end
      best_thread_hot_score = scored_children.map { |child| child[:thread_hot_score] }.max.to_f
      best_relative_thread_hot_score =
        scored_children.map { |child| child[:relative_thread_hot_score] }.max.to_f
      return if best_thread_hot_score <= 0.0 && best_relative_thread_hot_score <= 0.0

      minimum_score_ratio = hot_preload_min_relative_score
      minimum_thread_hot_score = best_thread_hot_score * minimum_score_ratio
      minimum_relative_thread_hot_score = best_relative_thread_hot_score * minimum_score_ratio
      scored_children.each do |child|
        if child[:thread_hot_score] < minimum_thread_hot_score &&
             child[:relative_thread_hot_score] < minimum_relative_thread_hot_score
          next
        end

        candidates << {
          post: child[:post],
          branch_post_number: branch_post_number,
          depth: depth,
          priority:
            hot_preload_priority(
              child[:thread_hot_score],
              child[:relative_thread_hot_score],
              depth,
            ),
          thread_hot_score: child[:thread_hot_score],
          hot_score: child[:hot_score],
          relative_thread_hot_score: child[:relative_thread_hot_score],
          relative_hot_score: child[:relative_hot_score],
        }
      end
    end

    def batch_load_siblings(ancestors, sort)
      root_ancestors, child_ancestors = ancestors.partition { |a| a.reply_to_post_number.nil? }

      siblings_map = {}

      if child_ancestors.present?
        parent_numbers = child_ancestors.map(&:reply_to_post_number).uniq

        order_expr = NestedReplies::Sort.sql_order_expression(sort)
        hot_join = sort == "hot" ? NestedReplies::Sort.hot_score_join_sql : ""

        visibility_conditions = +"#{visibility_sql} AND posts.post_number > 1"
        sql_params = {
          topic_id: topic.id,
          parent_numbers: parent_numbers,
          limit: SIBLINGS_PER_ANCESTOR,
          post_types: visible_post_types,
          whisper: Post.types[:whisper],
        }

        sibling_ids = DB.query_single(<<~SQL, **sql_params)
            SELECT id FROM (
              SELECT posts.id AS id, posts.reply_to_post_number,
                     ROW_NUMBER() OVER (PARTITION BY posts.reply_to_post_number ORDER BY #{order_expr}) AS rn
              FROM posts
              #{hot_join}
              WHERE posts.topic_id = :topic_id
                AND posts.reply_to_post_number IN (:parent_numbers)
                AND #{visibility_conditions}
            ) ranked
            WHERE rn <= :limit
          SQL

        if sibling_ids.present?
          loaded_siblings =
            load_posts_for_tree(topic.posts.with_deleted.where(id: sibling_ids)).to_a
          hot_scores = hot_scores_for_posts(loaded_siblings)
          grouped = loaded_siblings.group_by(&:reply_to_post_number)

          grouped.transform_values! do |posts|
            NestedReplies::Sort.sort_in_memory(posts, sort, hot_scores: hot_scores)
          end

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

    def hot_sorted_child_ids(parent_post_number, offset: 0, limit: CHILDREN_PER_PAGE)
      DB.query_single(
        <<~SQL,
          SELECT posts.id
          FROM posts
          LEFT JOIN nested_view_post_stats ON nested_view_post_stats.post_id = posts.id
          WHERE posts.topic_id = :topic_id
            AND posts.reply_to_post_number IS NOT DISTINCT FROM :parent_post_number
            AND #{visibility_sql}
            AND posts.post_number > 1
          ORDER BY #{NestedReplies::Sort.sql_order_expression("hot")}
          OFFSET :offset
          LIMIT :limit
        SQL
        topic_id: topic.id,
        parent_post_number: parent_post_number,
        post_types: visible_post_types,
        whisper: Post.types[:whisper],
        offset: offset,
        limit: limit,
      )
    end

    def flat_descendants_scope(parent_post_number, sort:, offset: 0, limit: CHILDREN_PER_PAGE)
      post_types = visible_post_types
      order_expr = NestedReplies::Sort.sql_order_expression(sort, posts_table: "p")

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
          LEFT JOIN nested_view_post_stats ON nested_view_post_stats.post_id = p.id
          WHERE #{visibility_sql(posts_table: "p")}
          ORDER BY #{order_expr}
          OFFSET :offset
          LIMIT :limit
        SQL
          topic_id: topic.id,
          parent_number: parent_post_number,
          post_types: post_types,
          whisper: Post.types[:whisper],
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
        .then do |scope|
          if guardian.user&.whisperer?
            scope.where(
              "post_type != :whisper OR action_code IS NULL OR action_code = ''",
              whisper: Post.types[:whisper],
            )
          else
            scope
          end
        end
        .group(:reply_to_post_number)
        .count
    end

    def tree_counts(posts)
      reply_counts = direct_reply_counts(posts.map(&:post_number))
      {
        reply_counts: reply_counts,
        descendant_counts: total_descendant_counts(posts, reply_counts: reply_counts),
      }
    end

    def total_descendant_counts(posts, reply_counts: nil)
      return {} if posts.empty?

      post_records = posts.select { |post| post.respond_to?(:post_number) }
      post_ids = posts.map { |post| post.respond_to?(:post_number) ? post.id : post }.compact.uniq

      stat_counts = cached_total_descendant_counts(post_ids)

      return stat_counts if post_records.empty?

      reply_counts ||= {}
      posts_needing_live_counts =
        post_records.select do |post|
          stat_counts[post.id].nil? ||
            stat_counts[post.id].to_i < reply_counts[post.post_number].to_i
        end

      return stat_counts if posts_needing_live_counts.empty?

      stat_counts.merge(
        live_total_descendant_counts(posts_needing_live_counts),
      ) { |_post_id, stat_count, live_count| [stat_count.to_i, live_count.to_i].max }
    end

    def live_total_descendant_counts(posts)
      return {} if posts.empty?

      post_ids_by_number = posts.index_by(&:post_number).transform_values(&:id)

      rows =
        DB.query(
          <<~SQL,
          WITH RECURSIVE descendants AS (
            SELECT roots.post_number AS root_post_number,
                   child.post_number,
                   child.post_type,
                   1 AS depth
            FROM posts roots
            JOIN posts child
              ON child.topic_id = roots.topic_id
             AND child.reply_to_post_number = roots.post_number
            WHERE roots.topic_id = :topic_id
              AND roots.id IN (:post_ids)
              AND child.post_number > 1
            UNION ALL
            SELECT descendants.root_post_number,
                   child.post_number,
                   child.post_type,
                   descendants.depth + 1
            FROM descendants
            JOIN posts child
              ON child.topic_id = :topic_id
             AND child.reply_to_post_number = descendants.post_number
            WHERE child.post_number > 1
              AND descendants.depth < :max_cte_depth
          )
          SELECT root_post_number, COUNT(*) AS total_descendant_count
          FROM descendants
          WHERE post_type IN (:post_types)
          GROUP BY root_post_number
        SQL
          topic_id: topic.id,
          post_ids: post_ids_by_number.values,
          post_types: visible_post_types,
          max_cte_depth: 500,
        )

      rows.each_with_object({}) do |row, counts|
        post_id = post_ids_by_number[row.root_post_number.to_i]
        counts[post_id] = row.total_descendant_count.to_i if post_id
      end
    end

    def cached_total_descendant_counts(post_ids)
      if guardian.user&.whisperer?
        DB
          .query(
            <<~SQL,
            WITH RECURSIVE roots AS (
              SELECT id, post_number
              FROM posts
              WHERE topic_id = :topic_id
                AND id IN (:post_ids)
            ), descendants AS (
              SELECT roots.id AS root_id, posts.post_number
              FROM roots
              JOIN posts ON posts.topic_id = :topic_id
                AND posts.reply_to_post_number = roots.post_number
                AND posts.post_number > 1
              UNION ALL
              SELECT descendants.root_id, posts.post_number
              FROM descendants
              JOIN posts ON posts.topic_id = :topic_id
                AND posts.reply_to_post_number = descendants.post_number
                AND posts.post_number > 1
            )
            SELECT descendants.root_id AS post_id, COUNT(*) AS descendant_count
            FROM descendants
            JOIN posts ON posts.topic_id = :topic_id
              AND posts.post_number = descendants.post_number
            WHERE #{visibility_sql}
            GROUP BY descendants.root_id
          SQL
            topic_id: topic.id,
            post_ids: post_ids.uniq,
            post_types: visible_post_types,
            whisper: Post.types[:whisper],
          )
          .to_h { |row| [row.post_id, row.descendant_count] }
      else
        NestedViewPostStat
          .where(post_id: post_ids.uniq)
          .pluck(:post_id, Arel.sql("total_descendant_count - whisper_total_descendant_count"))
          .to_h
      end
    end

    def hot_scores_for_posts(posts)
      return {} if posts.empty?

      NestedViewPostStat
        .where(post_id: posts.map(&:id).uniq)
        .pluck(
          :post_id,
          :thread_hot_score,
          :hot_score,
          :relative_thread_hot_score,
          :relative_hot_score,
        )
        .to_h do |post_id, thread_hot_score, hot_score, relative_thread_hot_score, relative_hot_score|
          [post_id, [thread_hot_score, hot_score, relative_thread_hot_score, relative_hot_score]]
        end
    end
  end
end
