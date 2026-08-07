# frozen_string_literal: true

module NestedReplies
  class TreeLoader
    PRELOAD_DEPTH = 3
    ROOTS_PER_PAGE = 20
    CHILDREN_PER_PAGE = 50
    PRELOAD_CHILDREN_PER_PARENT = 3
    HOT_PRELOAD_POST_BUDGET = 60
    HOT_PRELOAD_PER_ROOT_BUDGET = 15
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
      apply_sort(scope, sort)
    end

    def apply_sort(scope, sort)
      NestedReplies::Sort.apply(scope, effective_sort(sort))
    end

    def effective_sort(sort)
      @effective_sorts ||= {}
      @effective_sorts[sort] ||= HotScoreCache.effective_sort(topic, sort, requester: guardian.user)
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

    def batch_preload_tree(starting_posts, sort, max_depth:)
      sort = effective_sort(sort)
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
              SELECT ranked.id FROM (
                SELECT posts.id,
                       posts.reply_to_post_number,
                       ROW_NUMBER() OVER (
                         PARTITION BY posts.reply_to_post_number
                         ORDER BY #{order_expr}
                       ) AS rn
                FROM posts
                WHERE posts.topic_id = :topic_id
                  AND posts.reply_to_post_number IN (:parent_numbers)
                  AND posts.post_type IN (:post_types)
                  AND posts.post_number > 1
              ) ranked
              WHERE rn <= :limit
              ORDER BY ranked.reply_to_post_number, ranked.rn
            SQL
            topic_id: topic.id,
            parent_numbers: parent_numbers,
            limit: PRELOAD_CHILDREN_PER_PARENT,
            post_types: visible_post_types,
          )

        break if child_ids.empty?

        all_children = load_posts_for_tree(topic.posts.with_deleted.where(id: child_ids)).to_a
        child_positions = child_ids.each_with_index.to_h

        next_level = []
        all_children
          .group_by(&:reply_to_post_number)
          .each do |parent_number, child_posts|
            sorted = child_posts.sort_by { |child| child_positions.fetch(child.id) }
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
      max_preload_depth = [max_depth, configured_max_depth, PRELOAD_DEPTH].min
      visible_starting_posts =
        starting_posts.select do |post|
          visible_post_types.include?(post.post_type) &&
            (post.post_type != Post.types[:whisper] || post.action_code.blank?)
        end

      if visible_starting_posts.empty? || max_preload_depth <= 0 || HOT_PRELOAD_POST_BUDGET <= 0 ||
           HOT_PRELOAD_PER_ROOT_BUDGET <= 0 || PRELOAD_CHILDREN_PER_PARENT <= 0
        return { children_map: children_map, all_posts: all_posts }
      end

      # Discover only the three-wide, three-deep score frontier; hydrate posts after the global
      # and per-root budgets choose which branches should arrive expanded.
      candidate_rows = hot_preload_candidate_rows(visible_starting_posts, max_preload_depth)
      root_rows = candidate_rows.select { |row| row.depth.zero? }.index_by(&:post_number)
      rows_by_parent =
        candidate_rows.select { |row| row.depth.positive? }.group_by(&:reply_to_post_number)
      candidates =
        visible_starting_posts.filter_map do |post|
          row = root_rows[post.post_number]
          next if row.blank?

          {
            post_number: post.post_number,
            branch_post_number: post.post_number,
            depth: 0,
            priority: hot_preload_priority(row.thread_hot_score, 0),
            thread_hot_score: row.thread_hot_score.to_f,
            hot_score: row.hot_score.to_f,
          }
        end

      preloaded_count = 0
      branch_preloaded_counts = Hash.new(0)
      selected_rows_by_parent = {}

      while candidates.present? && preloaded_count < HOT_PRELOAD_POST_BUDGET
        candidates.sort_by! do |candidate|
          [
            -candidate[:priority],
            -candidate[:thread_hot_score],
            -candidate[:hot_score],
            candidate[:post_number],
          ]
        end

        candidate = candidates.shift
        parent_post_number = candidate[:post_number]
        branch_post_number = candidate[:branch_post_number]

        next if candidate[:depth] >= max_preload_depth
        next if selected_rows_by_parent.key?(parent_post_number)
        next if branch_preloaded_counts[branch_post_number] >= HOT_PRELOAD_PER_ROOT_BUDGET

        remaining_total_budget = HOT_PRELOAD_POST_BUDGET - preloaded_count
        remaining_branch_budget =
          HOT_PRELOAD_PER_ROOT_BUDGET - branch_preloaded_counts[branch_post_number]
        limit = [PRELOAD_CHILDREN_PER_PARENT, remaining_total_budget, remaining_branch_budget].min
        next if limit <= 0

        child_rows = rows_by_parent.fetch(parent_post_number, []).first(limit)
        next if child_rows.empty?

        selected_rows_by_parent[parent_post_number] = child_rows
        preloaded_count += child_rows.size
        branch_preloaded_counts[branch_post_number] += child_rows.size

        child_depth = candidate[:depth] + 1
        next if child_depth >= max_preload_depth

        child_rows.each do |child|
          candidates << {
            post_number: child.post_number,
            branch_post_number: branch_post_number,
            depth: child_depth,
            priority: hot_preload_priority(child.thread_hot_score, child_depth),
            thread_hot_score: child.thread_hot_score.to_f,
            hot_score: child.hot_score.to_f,
          }
        end
      end

      selected_ids = selected_rows_by_parent.values.flatten.map(&:id).uniq
      posts_by_id =
        if selected_ids.empty?
          {}
        else
          load_posts_for_tree(topic.posts.with_deleted.where(id: selected_ids)).to_a.index_by(&:id)
        end

      selected_rows_by_parent.each do |selected_parent_post_number, rows|
        children_map[selected_parent_post_number] = rows.filter_map { |row| posts_by_id[row.id] }
      end
      all_posts.concat(selected_ids.filter_map { |post_id| posts_by_id[post_id] })

      { children_map: children_map, all_posts: all_posts }
    end

    def hot_preload_candidate_rows(starting_posts, max_depth)
      thread_hot_score = NestedReplies::Sort.hot_score_expression("posts", :thread_hot_score)
      hot_score = NestedReplies::Sort.hot_score_expression("posts", :hot_score)

      DB.query(
        <<~SQL,
          WITH RECURSIVE preload_tree (
            id,
            post_number,
            reply_to_post_number,
            depth,
            path,
            thread_hot_score,
            hot_score
          ) AS (
            SELECT posts.id,
                   posts.post_number,
                   posts.reply_to_post_number,
                   0,
                   ARRAY[posts.post_number]::integer[],
                   #{thread_hot_score},
                   #{hot_score}
            FROM posts
            #{NestedReplies::Sort.hot_score_join_sql}
            WHERE posts.topic_id = :topic_id
              AND posts.id IN (:starting_post_ids)
              AND posts.post_type IN (:post_types)
              AND (
                posts.post_type != :whisper_post_type
                OR posts.action_code IS NULL
                OR posts.action_code = ''
              )

            UNION ALL

            SELECT children.id,
                   children.post_number,
                   children.reply_to_post_number,
                   preload_tree.depth + 1,
                   preload_tree.path || children.post_number,
                   children.thread_hot_score,
                   children.hot_score
            FROM preload_tree
            CROSS JOIN LATERAL (
              SELECT posts.id,
                     posts.post_number,
                     posts.reply_to_post_number,
                     #{thread_hot_score} AS thread_hot_score,
                     #{hot_score} AS hot_score
              FROM posts
              #{NestedReplies::Sort.hot_score_join_sql}
              WHERE posts.topic_id = :topic_id
                AND posts.reply_to_post_number = preload_tree.post_number
                AND posts.post_number > 1
                AND posts.post_type IN (:post_types)
                AND (
                  posts.post_type != :whisper_post_type
                  OR posts.action_code IS NULL
                  OR posts.action_code = ''
                )
                AND NOT posts.post_number = ANY(preload_tree.path)
              ORDER BY #{NestedReplies::Sort.sql_order_expression("hot")}
              LIMIT :children_per_parent
            ) children
            WHERE preload_tree.depth < :max_depth
          )
          SELECT id,
                 post_number,
                 reply_to_post_number,
                 depth,
                 thread_hot_score,
                 hot_score
          FROM preload_tree
          ORDER BY reply_to_post_number,
                   thread_hot_score DESC,
                   hot_score DESC,
                   post_number ASC
        SQL
        topic_id: topic.id,
        starting_post_ids: starting_posts.map(&:id),
        post_types: visible_post_types,
        whisper_post_type: Post.types[:whisper],
        children_per_parent: PRELOAD_CHILDREN_PER_PARENT,
        max_depth: max_depth,
      )
    end

    def hot_preload_priority(thread_hot_score, depth)
      thread_hot_score.to_f - SiteSetting.nested_replies_hot_preload_depth_penalty * depth
    end

    def batch_load_siblings(ancestors, sort)
      sort = effective_sort(sort)
      root_ancestors, child_ancestors = ancestors.partition { |a| a.reply_to_post_number.nil? }

      siblings_map = {}

      if child_ancestors.present?
        parent_numbers = child_ancestors.map(&:reply_to_post_number).uniq

        order_expr = NestedReplies::Sort.sql_order_expression(sort)
        hot_join = sort == "hot" ? NestedReplies::Sort.hot_score_join_sql : ""

        visibility_conditions = +"posts.post_type IN (:post_types) AND posts.post_number > 1"
        sql_params = {
          topic_id: topic.id,
          parent_numbers: parent_numbers,
          limit: SIBLINGS_PER_ANCESTOR,
          post_types: visible_post_types,
        }

        sibling_ids = DB.query_single(<<~SQL, **sql_params)
            SELECT ranked.id FROM (
              SELECT posts.id, posts.reply_to_post_number,
                     ROW_NUMBER() OVER (
                       PARTITION BY posts.reply_to_post_number
                       ORDER BY #{order_expr}
                     ) AS rn
              FROM posts
              #{hot_join}
              WHERE posts.topic_id = :topic_id
                AND posts.reply_to_post_number IN (:parent_numbers)
                AND #{visibility_conditions}
            ) ranked
            WHERE rn <= :limit
            ORDER BY ranked.reply_to_post_number, ranked.rn
          SQL

        if sibling_ids.present?
          loaded_siblings =
            load_posts_for_tree(topic.posts.with_deleted.where(id: sibling_ids)).to_a
          sibling_positions = sibling_ids.each_with_index.to_h
          grouped = loaded_siblings.group_by(&:reply_to_post_number)

          grouped.transform_values! do |posts|
            posts.sort_by { |post| sibling_positions.fetch(post.id) }
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

    def flat_descendants_scope(parent_post_number, sort:, offset: 0, limit: CHILDREN_PER_PAGE)
      sort = effective_sort(sort)
      post_types = visible_post_types
      order_expr = NestedReplies::Sort.sql_order_expression(sort, posts_table: "p")
      hot_join = sort == "hot" ? NestedReplies::Sort.hot_score_join_sql(posts_table: "p") : ""

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
          #{hot_join}
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
