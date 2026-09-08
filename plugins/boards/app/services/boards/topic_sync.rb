# frozen_string_literal: true

module Boards
  class TopicSync
    MAX_CARDS_PER_COLUMN = 200

    def self.backfill_board(board)
      return unless SiteSetting.boards_enabled?

      board = Board.includes(:columns).find(board.id) unless board.association(:columns).loaded?
      columns = board.columns.to_a

      # 1. Build topic-to-columns mapping via simple queries
      column_topic_ids = build_column_topic_map(board, columns)

      # 2. Build per-topic target columns (tagged = deterministic)
      catch_all_column_ids = columns.select { |col| col.tag_id.blank? }.map(&:id).to_set

      topic_to_tagged = Hash.new { |h, k| h[k] = Set.new }
      columns.each do |col|
        ids = column_topic_ids[col.id] || next
        ids.each { |tid| topic_to_tagged[tid] << col.id } if col.tag_id.present?
      end

      # 3. Load all existing topic cards for this board in one query
      existing_cards =
        board
          .cards
          .where(card_type: :topic)
          .where.not(topic_id: nil)
          .pluck(:id, :topic_id, :column_id)
      existing_by_topic = Hash.new { |h, k| h[k] = [] }
      existing_cards.each do |card_id, topic_id, column_id|
        existing_by_topic[topic_id] << { id: card_id, column_id: }
      end

      # 4. Diff: compute creates and deletes
      to_create = []
      to_delete = []

      all_topic_ids = (topic_to_tagged.keys + existing_by_topic.keys).uniq

      all_topic_ids.each do |topic_id|
        cards = existing_by_topic[topic_id]
        existing_column_ids = cards.map { |c| c[:column_id] }.to_set
        tagged_targets = topic_to_tagged[topic_id]

        # Tagged columns: deterministic
        tagged_targets.each do |col_id|
          to_create << { topic_id:, column_id: col_id } if existing_column_ids.exclude?(col_id)
        end

        # Unconstrained columns don't auto-receive cards. Manually-placed
        # cards in them are only preserved when no tagged column matches.
        if tagged_targets.empty?
          valid_columns = catch_all_column_ids
        else
          valid_columns = tagged_targets
        end

        cards.each { |c| to_delete << c[:id] if valid_columns.exclude?(c[:column_id]) }
      end

      # 5. Apply changes in bulk
      apply_bulk_changes(board, to_create:, to_delete:)
    end

    def self.sync_topic(topic)
      return unless SiteSetting.boards_enabled?
      return if topic.blank? || !topic.persisted? || topic.deleted_at.present?

      with_topic_sync_retry do
        Card.transaction do
          snapshot = fetch_sync_snapshot(topic)

          plan =
            compute_sync_plan(
              existing_cards: snapshot[:existing_cards],
              matching_placements: snapshot[:matching_placements],
            )
          next if plan[:remove_card_ids].blank? && plan[:create_targets].blank?

          execute_sync_changes(
            topic:,
            plan:,
            existing_cards: snapshot[:existing_cards],
            max_positions: snapshot[:max_positions],
            board_groups: snapshot[:board_groups],
          )
        end
      end
    end

    def self.remove_topic(topic_id)
      return unless SiteSetting.boards_enabled?

      rows = DB.query(<<~SQL, topic_id: topic_id)
          SELECT c.id AS card_id, c.board_id,
                 COALESCE(
                   ARRAY_AGG(DISTINCT acl_group_id) FILTER (WHERE acl_group_id IS NOT NULL),
                   '{}'::bigint[]
                 ) AS allowed_group_ids
          FROM discourse_kanban_cards c
          JOIN discourse_kanban_boards b ON b.id = c.board_id
          LEFT JOIN access_control_lists acl
            ON acl.target_id = b.id
           AND acl.target_type = 'Boards::Board'
           AND acl.permission IN ('view', 'edit', 'manage')
          LEFT JOIN LATERAL UNNEST(acl.allowed_group_ids) AS acl_groups(acl_group_id) ON TRUE
          WHERE c.topic_id = :topic_id
          GROUP BY c.id, c.board_id
        SQL

      return if rows.empty?

      deleted_by_board = {}
      board_groups = {}
      rows.each do |row|
        (deleted_by_board[row.board_id] ||= []) << row.card_id
        board_groups[row.board_id] ||= row.allowed_group_ids || []
      end

      Card.where(topic_id: topic_id).delete_all
      publish_sync_changes(board_groups:, deleted_by_board:, created_cards: [])
    end

    def self.fetch_sync_snapshot(topic)
      sanitized_tag_ids =
        if topic.tag_ids.present?
          "{#{topic.tag_ids.map(&:to_i).join(",")}}"
        else
          "{}"
        end

      sql = <<~SQL
        WITH matching AS (
          SELECT b.id AS board_id, c.id AS column_id, c.tag_id AS column_tag_id
          FROM discourse_kanban_boards b
          JOIN discourse_kanban_columns c ON c.board_id = b.id
          WHERE (b.category_ids != '{}' OR b.tag_ids != '{}')
            AND (b.category_ids = '{}' OR :topic_category_id = ANY(b.category_ids))
            AND (b.tag_ids = '{}' OR b.tag_ids && :topic_tag_ids)
            AND (c.tag_id IS NULL OR c.tag_id = ANY(:topic_tag_ids))
        ),
        max_positions AS (
          SELECT k.column_id, MAX(k.position) AS max_pos
          FROM discourse_kanban_cards k
          WHERE k.column_id IN (SELECT column_id FROM matching)
          GROUP BY k.column_id
        ),
        board_info AS (
          SELECT b.id AS board_id,
                 COALESCE(
                   ARRAY_AGG(DISTINCT acl_group_id) FILTER (WHERE acl_group_id IS NOT NULL),
                   '{}'::bigint[]
                 ) AS allowed_group_ids
          FROM discourse_kanban_boards b
          LEFT JOIN access_control_lists acl
            ON acl.target_id = b.id
           AND acl.target_type = 'Boards::Board'
           AND acl.permission IN ('view', 'edit', 'manage')
          LEFT JOIN LATERAL UNNEST(acl.allowed_group_ids) AS acl_groups(acl_group_id) ON TRUE
          WHERE b.id IN (
            SELECT board_id FROM matching
            UNION ALL
            SELECT board_id FROM discourse_kanban_cards WHERE topic_id = :topic_id
          )
          GROUP BY b.id
        )
        SELECT 'existing'::text AS source, ec.card_id, ec.board_id, ec.column_id,
               NULL::bigint AS column_tag_id, NULL::bigint AS max_pos,
               NULL::bigint[] AS allowed_group_ids
        FROM (
          SELECT c.id AS card_id, c.board_id, c.column_id
          FROM discourse_kanban_cards c
          JOIN discourse_kanban_boards b ON b.id = c.board_id
          WHERE c.topic_id = :topic_id
            AND (b.category_ids != '{}' OR b.tag_ids != '{}')
          FOR UPDATE OF c
        ) ec
        UNION ALL
        SELECT 'matching'::text, NULL, m.board_id, m.column_id,
               m.column_tag_id, NULL,
               NULL
        FROM matching m
        UNION ALL
        SELECT 'max_pos'::text, NULL, NULL, mp.column_id,
               NULL, mp.max_pos,
               NULL
        FROM max_positions mp
        UNION ALL
        SELECT 'board'::text, NULL, bi.board_id, NULL,
               NULL, NULL,
               bi.allowed_group_ids
        FROM board_info bi
      SQL

      existing_cards = []
      matching_placements = []
      max_positions = {}
      board_groups = {}

      DB
        .query(
          sql,
          topic_id: topic.id,
          topic_category_id: topic.category_id.to_i,
          topic_tag_ids: sanitized_tag_ids,
        )
        .each do |row|
          case row.source
          when "existing"
            existing_cards << [row.card_id, row.board_id, row.column_id]
          when "matching"
            matching_placements << {
              board_id: row.board_id,
              column_id: row.column_id,
              column_tag_id: row.column_tag_id,
            }
          when "max_pos"
            max_positions[row.column_id] = row.max_pos
          when "board"
            board_groups[row.board_id] = row.allowed_group_ids || []
          end
        end

      { existing_cards:, matching_placements:, max_positions:, board_groups: }
    end
    private_class_method :fetch_sync_snapshot

    def self.compute_sync_plan(existing_cards:, matching_placements:)
      # Build per-board sets: tagged column targets + catch-all column IDs
      tagged_targets = Hash.new { |h, k| h[k] = Set.new }
      catch_all_ids = Hash.new { |h, k| h[k] = Set.new }

      matching_placements.each do |row|
        if row[:column_tag_id].present?
          tagged_targets[row[:board_id]] << row[:column_id]
        else
          catch_all_ids[row[:board_id]] << row[:column_id]
        end
      end

      existing_by_board =
        existing_cards
          .group_by { |_, board_id, _| board_id }
          .transform_values do |rows|
            rows.map { |card_id, _, column_id| { id: card_id, column_id: } }
          end

      remove_card_ids = []
      create_targets = []

      all_board_ids = (tagged_targets.keys + catch_all_ids.keys + existing_by_board.keys).uniq

      all_board_ids.each do |board_id|
        cards = existing_by_board[board_id] || []
        board_tagged = tagged_targets[board_id]
        board_catch_alls = catch_all_ids[board_id]
        existing_column_ids = cards.map { |c| c[:column_id] }.to_set

        # Tagged columns: deterministic — create if missing
        board_tagged.each do |col_id|
          create_targets << { board_id:, column_id: col_id } if existing_column_ids.exclude?(col_id)
        end

        # Unconstrained columns don't auto-receive cards. Manually-placed
        # cards in them are only preserved when no tagged column matches.
        if board_tagged.empty?
          valid_columns = board_catch_alls
        else
          valid_columns = board_tagged
        end

        cards.each { |c| remove_card_ids << c[:id] if valid_columns.exclude?(c[:column_id]) }
      end

      { remove_card_ids:, create_targets: }
    end
    private_class_method :compute_sync_plan

    def self.execute_sync_changes(topic:, plan:, existing_cards:, max_positions:, board_groups:)
      # Delete — derive board mapping from existing_cards snapshot (no extra query)
      deleted_by_board = {}
      if plan[:remove_card_ids].present?
        remove_set = plan[:remove_card_ids].to_set
        existing_cards.each do |card_id, board_id, _|
          (deleted_by_board[board_id] ||= []) << card_id if remove_set.include?(card_id)
        end
        Card.where(id: plan[:remove_card_ids]).delete_all
      end

      # Create — positions precomputed from batch query
      created_cards = []
      if plan[:create_targets].present?
        system_user_id = Discourse.system_user.id
        running_positions = max_positions.dup

        now = Time.zone.now

        plan[:create_targets].each do |target|
          col_id = target[:column_id]
          running_positions[col_id] = (running_positions[col_id] || 0) + CardOrdering::GAP_SIZE

          card =
            Card.create!(
              board_id: target[:board_id],
              column_id: col_id,
              card_type: :topic,
              topic_id: topic.id,
              position: running_positions[col_id],
              column_changed_at: now,
              created_by_id: system_user_id,
              updated_by_id: system_user_id,
            )
          card.topic = topic
          created_cards << card
        end
      end

      # Trim columns that exceeded the cap — evict oldest topic cards
      if created_cards.present?
        affected_column_ids = plan[:create_targets].map { |t| t[:column_id] }.uniq
        evicted = trim_excess_cards(affected_column_ids)
        evicted.each { |board_id, card_ids| (deleted_by_board[board_id] ||= []).concat(card_ids) }
      end

      # Publish
      publish_sync_changes(board_groups:, deleted_by_board:, created_cards:)
    end
    private_class_method :execute_sync_changes

    def self.trim_excess_cards(column_ids)
      return {} if column_ids.blank?

      sanitized_col_ids = "{#{column_ids.map(&:to_i).join(",")}}"
      evicted = DB.query(<<~SQL, column_ids: sanitized_col_ids, max_cards: MAX_CARDS_PER_COLUMN)
          DELETE FROM discourse_kanban_cards
          WHERE id IN (
            SELECT id FROM (
              SELECT id, ROW_NUMBER() OVER (PARTITION BY column_id ORDER BY position DESC, id DESC) AS rn
              FROM discourse_kanban_cards
              WHERE column_id = ANY(:column_ids) AND card_type = #{Card.card_types[:topic]}
            ) ranked
            WHERE ranked.rn > :max_cards
          )
          RETURNING id, board_id
        SQL

      deleted_by_board = {}
      evicted.each { |row| (deleted_by_board[row.board_id] ||= []) << row.id }
      deleted_by_board
    end
    private_class_method :trim_excess_cards

    def self.publish_sync_changes(board_groups:, deleted_by_board:, created_cards:)
      deleted_by_board.each do |board_id, card_ids|
        card_ids.each do |card_id|
          publish_to_board(board_groups, board_id, type: "card_deleted", card_id: card_id)
        end
      end

      created_cards.each do |card|
        payload = CardSerializer.new(card, root: false).as_json.except("topic", :topic)
        publish_to_board(board_groups, card.board_id, type: "card_created", card: payload)
      end
    end
    private_class_method :publish_sync_changes

    def self.publish_to_board(board_groups, board_id, data)
      group_ids = board_groups[board_id]
      return if group_ids.nil?
      opts = {}
      if group_ids.present? && !group_ids.include?(Group::AUTO_GROUPS[:anonymous_users])
        opts[:group_ids] = group_ids
      end
      MessageBus.publish(
        "#{Publisher::CHANNEL_PREFIX}/#{board_id}",
        data.merge(client_id: nil),
        opts,
      )
    end
    private_class_method :publish_to_board

    def self.with_topic_sync_retry
      retries = 0

      begin
        yield
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::StatementInvalid => error
        raise unless unique_topic_card_violation?(error) && retries < 1

        retries += 1
        retry
      end
    end

    def self.unique_topic_card_violation?(error)
      [error, error.cause, error.cause&.cause].compact.any? do |candidate|
        candidate.message.include?("idx_kanban_cards_unique_topic_per_column") ||
          topic_card_constraint_name(candidate) == "idx_kanban_cards_unique_topic_per_column"
      end
    end

    def self.topic_card_constraint_name(error)
      return unless defined?(PG::Result)
      return unless error.respond_to?(:result)

      error.result&.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME)
    end

    def self.build_column_topic_map(board, columns)
      result = {}
      scope_base =
        Topic
          .listable_topics
          .visible
          .where.not(id: Category.where.not(topic_id: nil).select(:topic_id))
          .order(bumped_at: :desc)

      # Apply board-level category filter
      scope_base = scope_base.where(category_id: board.category_ids) if board.category_ids.present?

      # Apply board-level tag filter
      if board.tag_ids.present?
        scope_base = scope_base.where(id: TopicTag.where(tag_id: board.tag_ids).select(:topic_id))
      end

      columns.each do |col|
        if col.tag_id.present?
          ids =
            scope_base
              .where(id: TopicTag.where(tag_id: col.tag_id).select(:topic_id))
              .limit(MAX_CARDS_PER_COLUMN)
              .pluck(:id)
              .to_set
          result[col.id] = ids
        end
      end

      result
    end

    def self.apply_bulk_changes(board, to_create:, to_delete:)
      return if to_create.empty? && to_delete.empty?

      Card.transaction do
        Card.where(id: to_delete).delete_all if to_delete.any?

        if to_create.any?
          max_positions =
            board.cards.with_column.group(:column_id).maximum(:position).transform_values(&:to_i)

          system_user_id = Discourse.system_user.id
          now = Time.zone.now

          to_create.each do |entry|
            col_id = entry[:column_id]
            max_positions[col_id] = (max_positions[col_id] || -CardOrdering::GAP_SIZE) +
              CardOrdering::GAP_SIZE
            pos = max_positions[col_id]

            Card.insert!(
              {
                board_id: board.id,
                column_id: col_id,
                topic_id: entry[:topic_id],
                card_type: Card.card_types[:topic],
                position: pos,
                column_changed_at: now,
                created_by_id: system_user_id,
                updated_by_id: system_user_id,
                created_at: now,
                updated_at: now,
              },
            )
          end
        end
      end
    end
  end
end
